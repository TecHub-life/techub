module Images
  class OptimizeJob < ApplicationJob
    queue_as :images

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    # Optimize a generated image in the background and, if enabled, upload to Spaces and update artifacts.
    # Params:
    # - path: local file path to optimize
    # - login: profile login for artifact lookup
    # - kind: variant kind (e.g., "og", "card", "simple", or avatar kinds)
    # - format: optional forced format (png/jpg)
    # - quality: optional quality (jpg-only usual)
    # - min_bytes_for_bg: only process if file >= this many bytes (default: 300KB)
    # - upload: whether to upload the optimized image
    def perform(path:, login: nil, kind: nil, format: nil, quality: nil, min_bytes_for_bg: nil, upload: nil)
      started = Time.current
      path = Pathname.new(path)

      unless path.exist?
        StructuredLogger.warn(message: "image_optimize_skipped", reason: "not_found", path: path.to_s, login: login, kind: kind)
        return
      end

      size = path.size
      min_bytes = (min_bytes_for_bg.presence || ENV["IMAGE_OPT_BG_THRESHOLD"] || 300_000).to_i
      ext = path.extname.downcase
      type_ok = [ ".png", ".jpg", ".jpeg" ].include?(ext)

      unless type_ok
        StructuredLogger.info(message: "image_optimize_skipped", reason: "unsupported_type", path: path.to_s, ext: ext, login: login, kind: kind, size: size)
        return
      end

      if size < min_bytes
        StructuredLogger.info(message: "image_optimize_skipped", reason: "below_threshold", path: path.to_s, size: size, threshold: min_bytes, login: login, kind: kind)
        return
      end

      StructuredLogger.info(message: "image_optimize_started", path: path.to_s, size: size, login: login, kind: kind)

      # Write to a temp output then move in place to avoid partial writes
      tmp_out = path.sub_ext("#{path.extname}.opt")
      result = Images::OptimizeService.call(path: path.to_s, output_path: tmp_out.to_s, format: format, quality: quality)

      unless result.success?
        StructuredLogger.error(message: "image_optimize_failed", path: path.to_s, login: login, kind: kind, error: result.error&.message)
        raise result.error || StandardError.new("Image optimization failed")
      end

      optimized_path = Pathname.new(result.value[:output_path])
      # Replace original
      FileUtils.mv(optimized_path, path)

      new_size = path.size
      savings = size > 0 ? (((size - new_size) * 100.0) / size).round(1) : 0.0

      public_url = nil
      if should_upload?(upload)
        content_type = content_type_for_ext(path.extname)
        up = Storage::ActiveStorageUploadService.call(path: path.to_s, content_type: content_type, filename: path.basename.to_s)
        if up.success?
          public_url = up.value[:public_url]
        else
          StructuredLogger.warn(message: "image_optimize_upload_failed", path: path.to_s, login: login, kind: kind, error: up.error&.message)
        end
      end

      # Update artifact record if possible
      if login.present? && kind.present?
        profile = Profile.for_login(login).first || Profile.find_by(login: login)
        if profile
          begin
            rec = ProfileAssets::RecordService.call(
              profile: profile,
              kind: kind,
              local_path: path.to_s,
              public_url: public_url,
              mime_type: content_type_for_ext(path.extname),
              provider: "optimized"
            )
            if rec.failure?
              StructuredLogger.warn(message: "image_optimize_record_failed", login: login, kind: kind, error: rec.error&.message)
            end
          rescue StandardError => e
            StructuredLogger.warn(message: "image_optimize_record_failed", login: login, kind: kind, error: e.message)
          end
        end
      end

      StructuredLogger.info(
        message: "image_optimize_completed",
        path: path.to_s,
        login: login,
        kind: kind,
        duration_ms: ((Time.current - started) * 1000).to_i,
        original_size: size,
        optimized_size: new_size,
        savings_percent: savings,
        uploaded: public_url.present?,
        public_url: public_url
      )
    end

    private

    def content_type_for_ext(ext)
      case ext.to_s.downcase
      when ".jpg", ".jpeg" then "image/jpeg"
      else "image/png"
      end
    end

    def should_upload?(override)
      return !!override unless override.nil?
      Storage::ServiceProfile.remote_service?
    end
  end
end
