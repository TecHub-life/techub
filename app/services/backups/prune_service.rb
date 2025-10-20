require "aws-sdk-s3"

module Backups
  class PruneService < ApplicationService
    def initialize(bucket: nil, prefix: nil, retention_days: nil, keep_min: nil)
      creds = (Rails.application.credentials.dig(:do_spaces) rescue {}) || {}
      resolved_prefix = prefix || ENV["BACKUP_PREFIX"] || ENV["BACKUP_S3_PREFIX"] || creds[:backup_prefix] || "db_backups"
      @bucket = bucket || ENV["BACKUP_BUCKET"] || ENV["DO_SPACES_BACKUP_BUCKET"] || creds[:backup_bucket_name] || ENV["DO_SPACES_BUCKET"] || creds[:bucket_name]
      @prefix = resolved_prefix.to_s.gsub(%r{/*$}, "")
      @retention_days = (retention_days || ENV["BACKUP_RETENTION_DAYS"] || creds[:backup_retention_days] || 14).to_i
      @keep_min = [ (keep_min || ENV["BACKUP_KEEP_MIN"] || creds[:backup_keep_min] || 7).to_i, 1 ].max
    end

    def call
      return failure("Backup bucket not configured") if @bucket.to_s.strip.empty?

      client = s3_client
      base = File.join(@prefix, Rails.env) + "/"
      keys = []
      token = nil
      loop do
        resp = client.list_objects_v2(bucket: @bucket, prefix: base, continuation_token: token)
        keys.concat(Array(resp.contents).map { |o| o.key })
        break unless resp.is_truncated
        token = resp.next_continuation_token
      end

      groups = keys.group_by { |k| extract_group(base, k) }.reject { |g, _| g.nil? }
      return success({ deleted: 0, groups_considered: 0 }) if groups.empty?

      # Determine which groups to delete
      cutoff = Time.now.utc - (@retention_days * 86_400)
      ordered = groups.keys.map { |g| [ g, parse_ts(g) ] }.compact.sort_by { |(_g, t)| -t.to_i }
      keep = ordered.first(@keep_min).map(&:first)
      deletable = ordered.drop(@keep_min).map(&:first)
      if @retention_days > 0
        deletable.select! { |g| (parse_ts(g) || Time.at(0)) < cutoff }
      end

      to_delete = deletable.flat_map { |g| groups[g] }.uniq
      deleted = 0
      to_delete.each_slice(1000) do |slice|
        client.delete_objects(bucket: @bucket, delete: { objects: slice.map { |k| { key: k } } })
        deleted += slice.size
      end

      success({ deleted: deleted, groups_considered: groups.size, kept_groups: keep, deleted_groups: deletable })
    rescue StandardError => e
      failure(e)
    end

    private

    def extract_group(base, key)
      return nil unless key.start_with?(base)
      rest = key.delete_prefix(base)
      parts = rest.split("/")
      parts.first # timestamp component
    end

    def parse_ts(str)
      Time.strptime(str.to_s, "%Y%m%d-%H%M%S") rescue nil
    end

    def s3_client
      creds = (Rails.application.credentials.dig(:do_spaces) rescue {}) || {}
      endpoint = ENV["DO_SPACES_ENDPOINT"] || ENV["AWS_S3_ENDPOINT"] || creds[:endpoint]
      region = ENV["DO_SPACES_REGION"] || ENV["AWS_REGION"] || creds[:region] || "us-east-1"
      access_key = ENV["DO_SPACES_ACCESS_KEY_ID"] || ENV["AWS_ACCESS_KEY_ID"] || creds[:access_key_id]
      secret_key = ENV["DO_SPACES_SECRET_ACCESS_KEY"] || ENV["AWS_SECRET_ACCESS_KEY"] || creds[:secret_access_key]

      opts = { region: region }
      opts[:endpoint] = endpoint if endpoint.present?
      opts[:force_path_style] = true if endpoint.present?
      if access_key.present? && secret_key.present?
        opts[:credentials] = Aws::Credentials.new(access_key, secret_key)
      end
      Aws::S3::Client.new(opts)
    end
  end
end
