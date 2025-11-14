require "open3"

module Screenshots
  class CaptureCardService < ApplicationService
    # Single source of truth for social-target variants
    SOCIAL_VARIANTS = %w[
      x_profile_400
      x_header_1500x500
      x_feed_1600x900
      fb_post_1080
      ig_portrait_1080x1350
      ig_landscape_1080x566
      fb_cover_851x315
      linkedin_cover_1584x396
      youtube_cover_2560x1440
    ].freeze
    DEFAULT_WIDTHS = {
      # Card and simple variants
      "og" => 1200,
      "card" => 1280,
      "card_pro" => 1280,
      "simple" => 1280,
      "banner" => 1500,
      "og_pro" => 1200,
      # Social targets
      "x_profile_400" => 400,
      "x_header_1500x500" => 1500,
      "x_feed_1600x900" => 1600,
      "fb_post_1080" => 1080,
      "ig_portrait_1080x1350" => 1080,
      "ig_landscape_1080x566" => 1080,
      "fb_cover_851x315" => 851,
      "linkedin_cover_1584x396" => 1584,
      "youtube_cover_2560x1440" => 2560,
      # Explicit OG alias
      "og_1200x630" => 1200
    }.freeze
    DEFAULT_HEIGHTS = {
      # Card and simple variants
      "og" => 630,
      "og_pro" => 630,
      "card" => 720,
      "card_pro" => 720,
      "simple" => 720,
      "banner" => 500,
      # Social targets
      "x_profile_400" => 400,
      "x_header_1500x500" => 500,
      "x_feed_1600x900" => 900,
      "ig_portrait_1080x1350" => 1350,
      "ig_landscape_1080x566" => 566,
      "fb_post_1080" => 1080,
      "fb_cover_851x315" => 315,
      "linkedin_cover_1584x396" => 396,
      "youtube_cover_2560x1440" => 1440
    }.freeze

    def initialize(login:, variant: "og", host: nil, output_path: nil, wait_ms: 500, type: nil, quality: 85)
      @login = login.to_s.downcase
      @variant = variant.to_s
      resolved_host = resolve_host(host)
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
      @goto_timeout_ms = fetch_setting_int(:screenshot_goto_timeout_ms, env: "SCREENSHOT_GOTO_TIMEOUT_MS", default: 60_000)
      @wait_until = normalize_wait_until(fetch_setting(:screenshot_wait_until, env: "SCREENSHOT_WAIT_UNTIL", default: "networkidle0"))
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
      debug_dir = Rails.root.join("public", "generated", login, "debug", variant, Time.now.utc.strftime("%Y%m%dT%H%M%S"))
      begin
        FileUtils.mkdir_p(debug_dir)
      rescue StandardError
        # best-effort
      end
      cmd = [
        "node",
        script_rel,
        "--url", url,
        "--out", path.to_s,
        "--width", width.to_s,
        "--height", height.to_s,
        "--wait", wait_ms.to_s,
        "--type", type,
        "--quality", quality.to_s,
        "--gotoTimeout", @goto_timeout_ms.to_s,
        "--waitUntil", @wait_until,
        "--debug", "1",
        "--debugDir", debug_dir.to_s
      ]

      if Rails.env.test?
        # In test, avoid invoking Node: create a tiny PNG header as a placeholder
        File.binwrite(path, "\x89PNG\r\n")
      else
        # Ensure we execute with a fixed working directory and safe argument array
        out_str, err_str, status = Open3.capture3(*cmd, chdir: Rails.root.to_s)
        unless status.success?
          # Persist stdout/stderr to debug files to avoid shipping large payloads to Axiom
          begin
            File.write(File.join(debug_dir, "stdout.log"), out_str.to_s)
          rescue StandardError
          end
          begin
            File.write(File.join(debug_dir, "stderr.log"), err_str.to_s)
          rescue StandardError
          end
          log_meta = { cmd: cmd.join(" "), debug_dir: debug_dir.to_s, stdout_bytes: out_str.to_s.bytesize, stderr_bytes: err_str.to_s.bytesize, url: url, variant: variant, login: login }
          StructuredLogger.error(message: "screenshot_command_failed", service: self.class.name, metadata: log_meta) if defined?(StructuredLogger)
          return failure(StandardError.new("Screenshot command failed"), metadata: log_meta)
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
          meta = { login: login, variant: variant, url: url, path: path.to_s, size: size_bytes }
          StructuredLogger.error(message: "screenshot_empty", service: self.class.name, metadata: meta) if defined?(StructuredLogger)
          return failure(StandardError.new("screenshot_empty"), metadata: meta)
        end
      end

      public_url = nil
      if upload_enabled? && Storage::ServiceProfile.remote_service?
        begin
          upload = Storage::ActiveStorageUploadService.call(
            path: path.to_s,
            content_type: mime_type,
            filename: File.basename(path)
          )
          if upload.success?
            public_url = upload.value[:public_url]
          else
            StructuredLogger.warn(message: "screenshot_upload_failed", login: login, variant: variant, error: upload.error&.message, path: path.to_s) if defined?(StructuredLogger)
          end
        rescue StandardError => e
          StructuredLogger.warn(message: "screenshot_upload_exception", login: login, variant: variant, error: e.message, path: path.to_s) if defined?(StructuredLogger)
        end
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

    def resolve_host(custom_host)
      candidate = custom_host.presence || ENV["APP_HOST"].presence || (defined?(AppHost) ? AppHost.current : nil)
      candidate.presence || "http://127.0.0.1:3000"
    end

    def default_output_path
      ext = (type == "png") ? "png" : "jpg"
      Rails.root.join("public", "generated", login, "#{variant}.#{ext}")
    end

    def mime_type
      type == "png" ? "image/png" : "image/jpeg"
    end

    def upload_enabled?
      return true if Rails.env.production?

      AppSetting.get_bool(:generated_image_upload, default: true)
    rescue StandardError
      false
    end

    # Upload support is governed strictly by Active Storage configuration.
    def normalize_wait_until(value)
      str = value.to_s.downcase
      return "networkidle0" if str.include?("idle0")
      return "networkidle2" if str.include?("idle2")
      return "domcontentloaded" if str.include?("dom")
      "networkidle0"
    end

    def fetch_setting(key, env:, default: nil)
      # Prefer application setting; fall back to env; then default
      begin
        app_val = AppSetting.get(key, default: nil)
      rescue StandardError
        app_val = nil
      end
      return app_val if app_val.present?
      ENV[env].presence || default
    end

    def fetch_setting_int(key, env:, default: nil)
      v = fetch_setting(key, env: env, default: default)
      v.to_i
    end
  end
end
