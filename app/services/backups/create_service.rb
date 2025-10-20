require "aws-sdk-s3"
require "digest"

module Backups
  class CreateService < ApplicationService
    def initialize(bucket: nil, prefix: nil)
      creds = (Rails.application.credentials.dig(:do_spaces) rescue {}) || {}
      resolved_prefix = prefix || ENV["BACKUP_PREFIX"] || ENV["BACKUP_S3_PREFIX"] || creds[:backup_prefix] || "db_backups"
      @bucket = bucket || ENV["BACKUP_BUCKET"] || ENV["DO_SPACES_BACKUP_BUCKET"] || creds[:backup_bucket_name] || ENV["DO_SPACES_BUCKET"] || creds[:bucket_name]
      @prefix = resolved_prefix.to_s.gsub(%r{/*$}, "") # trim trailing slashes
    end

    def call
      return failure("Backup bucket not configured") if @bucket.to_s.strip.empty?

      files = Dir[Rails.root.join("storage", "*.sqlite3")]
      return failure("No database files found in storage/") if files.empty?

      ts = Time.now.utc.strftime("%Y%m%d-%H%M%S")
      env = Rails.env
      client = s3_client
      uploaded = []

      files.each do |path|
        key = File.join(@prefix, env, ts, File.basename(path))
        sha256 = Digest::SHA256.file(path).hexdigest rescue nil
        File.open(path, "rb") do |io|
          client.put_object(
            bucket: @bucket,
            key: key,
            body: io,
            content_type: "application/octet-stream",
            acl: "private",
            metadata: sha256 ? { "sha256" => sha256 } : {}
          )
        end
        uploaded << key
      end

      success({ bucket: @bucket, keys: uploaded }, metadata: { count: uploaded.size, timestamp: ts })
    rescue StandardError => e
      failure(e)
    end

    private

    def s3_client
      # Prefer DigitalOcean Spaces credentials; allow env overrides
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
