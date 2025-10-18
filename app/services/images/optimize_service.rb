module Images
  class OptimizeService < ApplicationService
    def initialize(path:, output_path: nil, format: nil, quality: 85)
      @path = Pathname.new(path)
      @output_path = output_path.present? ? Pathname.new(output_path) : @path
      @format = format&.to_s&.downcase
      @quality = quality.to_i
    end

    def call
      return failure(StandardError.new("File not found"), metadata: { path: path.to_s }) unless path.exist?

      if Rails.env.test?
        # In tests, avoid invoking external processors
        FileUtils.cp(path, output_path) unless output_path == path
        return success({ output_path: output_path.to_s, format: effective_format, quality: quality })
      end

      # Prefer ImageProcessing with vips only when explicitly enabled
      if use_vips?
        begin
          require "image_processing/vips"
          processor = ImageProcessing::Vips.source(path.to_s)
          processor = processor.saver(strip: true)

          case effective_format
          when "jpg", "jpeg"
            dst = ensure_ext(output_path.to_s, ".jpg")
            processed = processor
              .convert("jpg")
              .saver(quality: quality.clamp(1, 100), interlace: true)
              .call(destination: dst)
          else # png
            dst = ensure_ext(output_path.to_s, ".png")
            processed = processor.convert("png").call(destination: dst)
          end

          return success({ output_path: processed.to_s, format: effective_format, quality: quality })
        rescue LoadError
          # fall through to magick
        rescue StandardError => e
          # Any runtime error falls back to magick for safety
          StructuredLogger.warn(message: "vips_optimize_failed", error: e.message, path: path.to_s) if defined?(StructuredLogger)
        end
      end

      # Fallback: ImageMagick CLI
      cmd = build_magick_command
      ok = system(*cmd)
      return failure(StandardError.new("Image optimization failed"), metadata: { cmd: cmd.join(" ") }) unless ok
      success({ output_path: output_path.to_s, format: effective_format, quality: quality })
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :path, :output_path, :format, :quality

    def use_vips?
      # Opt-in only: enable when IMAGE_OPT_VIPS is truthy
      %w[1 true yes].include?(ENV["IMAGE_OPT_VIPS"].to_s.downcase)
    end

    def build_magick_command
      # Use ImageMagick via `magick` (IM7) when available; otherwise fall back to `convert` (IM6)
      cli = imagemagick_cli
      src = path.to_s
      dst = output_path.to_s
      case effective_format
      when "jpg", "jpeg"
        [ cli, src, "-strip", "-interlace", "Plane", "-quality", quality.to_s, ensure_ext(dst, ".jpg") ]
      else # png
        [ cli, src, "-strip", "-define", "png:compression-level=9", ensure_ext(dst, ".png") ]
      end
    end

    def effective_format
      return format if %w[png jpg jpeg].include?(format)
      ext = path.extname.downcase.delete_prefix(".")
      %w[png jpg jpeg].include?(ext) ? ext : "png"
    end

    def ensure_ext(dst, ext)
      File.extname(dst).downcase == ext ? dst : dst.sub(/\.[^.]+\z/, ext)
    end

    def imagemagick_cli
      # Allow override via ENV
      override = ENV["IM_CLI"].to_s.strip
      return override unless override.empty?

      # Prefer magick when available, otherwise use convert
      magick_available? ? "magick" : "convert"
    end

    def magick_available?
      # Quietly check for magick
      system("magick -version > /dev/null 2>&1")
    end
  end
end
