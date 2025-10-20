require "aws-sdk-s3"

module Backups
  class DoctorService < ApplicationService
    Result = Struct.new(:bucket, :prefix, :region, :endpoint, :can_list, :sample_count, :error, keyword_init: true)

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
      prefix = File.join(@prefix, Rails.env) + "/"
      can_list = false
      sample = 0
      begin
        resp = client.list_objects_v2(bucket: @bucket, prefix: prefix, max_keys: 5)
        can_list = true
        sample = Array(resp.contents).size
      rescue StandardError => e
        return failure(e, metadata: meta(can_list: false, sample: 0))
      end

      success(Result.new(bucket: @bucket, prefix: @prefix, region: @region, endpoint: @endpoint, can_list: can_list, sample_count: sample), metadata: meta(can_list: can_list, sample: sample))
    rescue StandardError => e
      failure(e, metadata: meta(can_list: false, sample: 0))
    end

    private

    def meta(can_list:, sample:)
      { bucket: @bucket, prefix: @prefix, region: @region, endpoint: @endpoint, can_list: can_list, sample_count: sample }
    end

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
