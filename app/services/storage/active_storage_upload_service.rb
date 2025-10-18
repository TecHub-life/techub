module Storage
  class ActiveStorageUploadService < ApplicationService
    def initialize(path:, content_type: "image/png", filename: nil)
      @path = Pathname.new(path)
      @content_type = content_type
      @filename = filename.presence || @path.basename.to_s
    end

    def call
      return failure(StandardError.new("File not found"), metadata: { path: path.to_s }) unless path.exist?

      # Ensure ActiveStorage has URL options configured when using local/Disk service in production-like mode
      # so that Blob#url can generate a full URL.
      begin
        if defined?(ActiveStorage::Current) && (ActiveStorage::Current.url_options.blank?)
          host_env = ENV["APP_HOST"].presence || "http://localhost:3000"
          require "uri"
          uri = URI.parse(host_env) rescue nil
          url_opts = if uri && uri.host
            opts = { host: uri.host }
            opts[:protocol] = uri.scheme if uri.scheme
            # Only set port when it's non-standard
            opts[:port] = uri.port if uri.port && ![ 80, 443 ].include?(uri.port)
            opts
          else
            { host: host_env.sub(/^https?:\/\//, "") }
          end
          ActiveStorage::Current.url_options = url_opts
        end
      rescue StandardError
        # best-effort; do not fail uploads due to url_options parsing
      end

      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(path, "rb"),
        filename: filename,
        content_type: content_type
      )

      # For public services (e.g., DO Spaces), .url returns a CDN/public URL when configured.
      # For Disk/local in production-like mode, fall back to a relative blob path to avoid host requirements.
      public_url = begin
        blob.url
      rescue ArgumentError
        Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
      end

      success({ public_url: public_url, key: blob.key, filename: blob.filename.to_s })
    rescue StandardError => e
      failure(e, metadata: { path: path.to_s, filename: filename, content_type: content_type })
    end

    private

    attr_reader :path, :content_type, :filename
  end
end
