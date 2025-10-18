module Screenshots
  class CaptureCardService < ApplicationService
    DEFAULT_WIDTHS = {
      "og" => 1200,
      "card" => 1280,
      "simple" => 1280
    }.freeze
    DEFAULT_HEIGHTS = {
      "og" => 630,
      "card" => 720,
      "simple" => 720
    }.freeze

    def initialize(login:, variant: "og", host: nil, output_path: nil, wait_ms: 500, type: nil, quality: 85)
      @login = login.to_s.downcase
      @variant = variant.to_s
      @host = host.presence || ENV["APP_HOST"].presence || "http://127.0.0.1:3000"
      @output_path = output_path
      @wait_ms = wait_ms.to_i
      # In test env, keep PNG for compatibility with existing tests
      default_type = Rails.env.test? ? "png" : "jpeg"
      @type = %w[jpeg png].include?(type.to_s.downcase) ? type.to_s.downcase : default_type
      @quality = quality.to_i
    end

    def call
      return failure(StandardError.new("login is required")) if login.blank?
      return failure(StandardError.new("invalid variant")) unless DEFAULT_WIDTHS.key?(variant)

      width = DEFAULT_WIDTHS[variant]
      height = DEFAULT_HEIGHTS[variant]
      url = File.join(host, "/cards/#{login}/#{variant}")

      path = Pathname.new(output_path.presence || default_output_path)
      FileUtils.mkdir_p(path.dirname)

      cmd = [
        "node",
        Rails.root.join("script", "screenshot.js").to_s,
        "--url", url,
        "--out", path.to_s,
        "--width", width.to_s,
        "--height", height.to_s,
        "--wait", wait_ms.to_s,
        "--type", type,
        "--quality", quality.to_s
      ]

      if Rails.env.test?
        # In test, avoid invoking Node: create a tiny PNG header as a placeholder
        File.binwrite(path, "\x89PNG\r\n")
      else
        ok = Kernel.system(*cmd)
        return failure(StandardError.new("Screenshot command failed"), metadata: { cmd: cmd.join(" ") }) unless ok
      end

      return failure(StandardError.new("Screenshot not found"), metadata: { expected: path.to_s }) unless File.exist?(path)

      public_url = nil
      if upload_enabled?
        upload = Storage::ActiveStorageUploadService.call(path: path.to_s, content_type: mime_type, filename: File.basename(path))
        return upload if upload.failure?
        public_url = upload.value[:public_url]
      end

      success(
        { output_path: path.to_s, mime_type: mime_type, url: url, public_url: public_url, width: width, height: height },
        metadata: { login: login, variant: variant, output_path: path.to_s, public_url: public_url, width: width, height: height }
      )
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :login, :variant, :host, :output_path, :wait_ms, :type, :quality

    def default_output_path
      ext = (type == "png") ? "png" : "jpg"
      Rails.root.join("public", "generated", login, "#{variant}.#{ext}")
    end

    def mime_type
      type == "png" ? "image/png" : "image/jpeg"
    end

    def upload_enabled?
      flag = ENV["GENERATED_IMAGE_UPLOAD"].to_s.downcase
      [ "1", "true", "yes" ].include?(flag) || Rails.env.production?
    end
  end
end
