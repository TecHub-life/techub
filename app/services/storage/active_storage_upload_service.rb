module Storage
  class ActiveStorageUploadService < ApplicationService
    def initialize(path:, content_type: "image/png", filename: nil)
      @path = Pathname.new(path)
      @content_type = content_type
      @filename = filename.presence || @path.basename.to_s
    end

    def call
      return failure(StandardError.new("File not found"), metadata: { path: path.to_s }) unless path.exist?

      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(path, "rb"),
        filename: filename,
        content_type: content_type
      )

      # For public services (e.g., DO Spaces), .url returns a CDN/public URL when configured.
      success(
        {
          public_url: blob.url,
          key: blob.key,
          filename: blob.filename.to_s
        }
      )
    rescue StandardError => e
      failure(e, metadata: { path: path.to_s, filename: filename, content_type: content_type })
    end

    private

    attr_reader :path, :content_type, :filename
  end
end
