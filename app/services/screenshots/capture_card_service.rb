require "open3"

module Screenshots
  class CaptureCardService < ApplicationService
    # Single source of truth for social-target variants
    SOCIAL_VARIANTS = %w[
      x_profile_400
      fb_post_1080
      ig_portrait_1080x1350
    ].freeze
    DEFAULT_WIDTHS = {
      # Existing
      "og" => 1200,
      "card" => 1280,
      "simple" => 1280,
      "banner" => 1500,
      # Social targets (only those with templates/views in app/views/cards)
      "x_profile_400" => 400,
      "fb_post_1080" => 1080,
      "ig_portrait_1080x1350" => 1080,
      # Explicit OG alias
      "og_1200x630" => 1200
    }.freeze
    DEFAULT_HEIGHTS = {
      # Existing
      "og" => 630,
      "card" => 720,
      "simple" => 720,
      "banner" => 500,
      # Social targets (only those with templates/views)
      "x_profile_400" => 400,
      "ig_portrait_1080x1350" => 1350,
      "fb_post_1080" => 1080
    }.freeze

    def initialize(login:, variant: "og", host: nil, output_path: nil, wait_ms: 500, type: nil, quality: 85)
      @login = login.to_s.downcase
      @variant = variant.to_s
      resolved_host = host.presence || ENV["APP_HOST"].presence || (defined?(AppHost) ? AppHost.current : nil) || "http://127.0.0.1:3000"
      # Validate host to be an http(s) URL
      begin
        uri = URI.parse(resolved_host.to_s)
        raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        @host = uri.to_s
      rescue URI::InvalidURIError
        @host = "http://127.0.0.1:3000"
      end
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
      url = URI.join(host.to_s.end_with?("/") ? host.to_s : "#{host}/", "cards/#{login}/#{variant}").to_s

      path = Pathname.new(output_path.presence || default_output_path)
      FileUtils.mkdir_p(path.dirname)

      script_rel = File.join("script", "screenshot.js")
      cmd = [
        "node",
        script_rel,
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
        # Ensure we execute with a fixed working directory and safe argument array
        out_str, err_str, status = Open3.capture3(*cmd, chdir: Rails.root.to_s)
        unless status.success?
          StructuredLogger.error(message: "screenshot_command_failed", cmd: cmd.join(" "), stdout: out_str, stderr: err_str) if defined?(StructuredLogger)
          return failure(StandardError.new("Screenshot command failed"), metadata: { cmd: cmd.join(" "), stdout: out_str, stderr: err_str })
        end
      end

      return failure(StandardError.new("Screenshot not found"), metadata: { expected: path.to_s }) unless File.exist?(path)

      # Guard against zero-byte/invalid outputs in non-test environments
      unless Rails.env.test?
        begin
          size_bytes = File.size(path)
        rescue StandardError
          size_bytes = 0
        end
        if size_bytes.to_i <= 1024
          StructuredLogger.error(message: "screenshot_empty", login: login, variant: variant, url: url, path: path.to_s, size: size_bytes) if defined?(StructuredLogger)
          return failure(StandardError.new("screenshot_empty"), metadata: { expected: path.to_s, size: size_bytes, url: url })
        end
      end

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
      if defined?(AppSetting)
        return AppSetting.get_bool(:generated_image_upload, default: Rails.env.production?)
      end
      flag = ENV["GENERATED_IMAGE_UPLOAD"].to_s.downcase
      [ "1", "true", "yes" ].include?(flag) || Rails.env.production?
    end
  end
end
