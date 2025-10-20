require "aws-sdk-s3"

module Backups
  class RestoreService < ApplicationService
    def initialize(bucket: ENV["BACKUP_S3_BUCKET"], prefix: ENV["BACKUP_S3_PREFIX"] || "db_backups", group: nil, confirm: ENV["CONFIRM"])
      @bucket = bucket
      @prefix = prefix.to_s.gsub(%r{/*$}, "")
      @group = group # timestamp string or 'latest'
      @confirm = confirm
    end

    def call
      return failure("Restore is disabled; set ALLOW_DB_RESTORE=1") unless allowed?
      return failure("CONFIRM=YES required") unless @confirm.to_s.upcase == "YES"
      return failure("BACKUP_S3_BUCKET not configured") if @bucket.to_s.strip.empty?

      client = Aws::S3::Client.new
      base = File.join(@prefix, Rails.env) + "/"

      group = @group
      if group.to_s.strip.empty? || group == "latest"
        keys = list_keys(client, base)
        groups = keys.group_by { |k| extract_group(base, k) }.reject { |g, _| g.nil? }
        return failure("No backups found") if groups.empty?
        group = groups.keys.sort_by { |g| parse_ts(g) || Time.at(0) }.last
      end

      keys = list_keys(client, File.join(base, group) + "/")
      return failure("Backup group not found: #{group}") if keys.empty?

      storage_dir = Rails.root.join("storage")
      keys.each do |key|
        filename = key.split("/").last
        target = storage_dir.join(filename)
        io = StringIO.new
        client.get_object(bucket: @bucket, key: key) { |chunk| io.write(chunk) }
        io.rewind
        File.binwrite(target, io.read)
      end

      success({ restored_group: group, files: keys.map { |k| k.split("/").last } })
    rescue StandardError => e
      failure(e)
    end

    private

    def allowed?
      Rails.env.development? || ENV["ALLOW_DB_RESTORE"] == "1"
    end

    def list_keys(client, prefix)
      keys = []
      token = nil
      loop do
        resp = client.list_objects_v2(bucket: @bucket, prefix: prefix, continuation_token: token)
        keys.concat(Array(resp.contents).map { |o| o.key })
        break unless resp.is_truncated
        token = resp.next_continuation_token
      end
      keys
    end

    def extract_group(base, key)
      return nil unless key.start_with?(base)
      rest = key.delete_prefix(base)
      parts = rest.split("/")
      parts.first
    end

    def parse_ts(str)
      Time.strptime(str.to_s, "%Y%m%d-%H%M%S") rescue nil
    end
  end
end
