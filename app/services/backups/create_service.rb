require "aws-sdk-s3"
require "digest"

module Backups
  class CreateService < ApplicationService
    def initialize(bucket: ENV["BACKUP_S3_BUCKET"], prefix: ENV["BACKUP_S3_PREFIX"] || "db_backups")
      @bucket = bucket
      @prefix = prefix.to_s.gsub(%r{/*$}, "") # trim trailing slashes
    end

    def call
      return failure("BACKUP_S3_BUCKET not configured") if @bucket.to_s.strip.empty?

      files = Dir[Rails.root.join("storage", "*.sqlite3")]
      return failure("No database files found in storage/") if files.empty?

      ts = Time.now.utc.strftime("%Y%m%d-%H%M%S")
      env = Rails.env
      client = Aws::S3::Client.new
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
            metadata: sha256 ? { "sha256" => sha256 } : {}
          )
        end
        uploaded << key
      end

      success({ bucket: @bucket, keys: uploaded }, metadata: { count: uploaded.size, timestamp: ts })
    rescue StandardError => e
      failure(e)
    end
  end
end
