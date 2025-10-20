require "aws-sdk-s3"

module Backups
  class WriteProbeService < ApplicationService
    def initialize(bucket: nil, prefix: nil)
      creds = (Rails.application.credentials.dig(:do_spaces) rescue {}) || {}
      resolved_prefix = prefix || ENV["BACKUP_PREFIX"] || ENV["BACKUP_S3_PREFIX"] || creds[:backup_prefix] || "db_backups"
      @bucket = bucket || ENV["BACKUP_BUCKET"] || ENV["DO_SPACES_BACKUP_BUCKET"] || creds[:backup_bucket_name] || ENV["DO_SPACES_BUCKET"] || creds[:bucket_name]
      @prefix = resolved_prefix.to_s.gsub(%r{/*$}, "")
      @endpoint = ENV["DO_SPACES_ENDPOINT"] || ENV["AWS_S3_ENDPOINT"] || creds[:endpoint]
      @region = ENV["DO_SPACES_REGION"] || ENV["AWS_REGION"] || creds[:region] || "us-east-1"
      @access_key = ENV["DO_SPACES_ACCESS_KEY_ID"] || ENV["AWS_ACCESS_KEY_ID"] || creds[:access_key_id]
      @secret_key = ENV["DO_SPACES_SECRET_ACCESS_KEY"] || ENV["AWS_SECRET_ACCESS_KEY"] || creds[:secret_access_key]
    end

    def call
      return failure("Backup bucket not configured") if @bucket.to_s.strip.empty?

      client = s3_client
      key = File.join(@prefix, Rails.env, "probe-#{Time.now.utc.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(4)}.txt")
      body = "techub backup write probe @ #{Time.now.utc.iso8601}\n"

      client.put_object(bucket: @bucket, key: key, body: body, content_type: "text/plain", acl: "private")
      client.delete_object(bucket: @bucket, key: key)

      success({ bucket: @bucket, key: key })
    rescue StandardError => e
      failure(e)
    end

    private

    def s3_client
      opts = { region: @region }
      opts[:endpoint] = @endpoint if @endpoint.present?
      opts[:force_path_style] = true if @endpoint.present?
      if @access_key.present? && @secret_key.present?
        opts[:credentials] = Aws::Credentials.new(@access_key, @secret_key)
      end
      Aws::S3::Client.new(opts)
    end
  end
end
