module Images
  class ResizeService < ApplicationService
    def initialize(src_path:, output_path:, width:, height:, fit: "cover")
      @src_path = Pathname.new(src_path)
      @output_path = Pathname.new(output_path)
      @width = width.to_i
      @height = height.to_i
      @fit = fit.to_s
    end

    def call
      return failure(StandardError.new("Source not found"), metadata: { path: src_path.to_s }) unless src_path.exist?
      return failure(StandardError.new("Invalid target size")) if width <= 0 || height <= 0

      if Rails.env.test?
        FileUtils.mkdir_p(output_path.dirname)
        FileUtils.cp(src_path, output_path)
        return success({ output_path: output_path.to_s, width: width, height: height })
      end

      if use_vips?
        begin
          require "image_processing/vips"
          processor = ImageProcessing::Vips.source(src_path.to_s)
          dst = ensure_ext(output_path.to_s, ".jpg")

          case fit
          when "contain"
            processed = processor.resize_to_limit(width, height).convert("jpg").saver(quality: 85, interlace: true).call(destination: dst)
          when "fill"
            processed = processor.resize_to_fill(width, height).convert("jpg").saver(quality: 85, interlace: true).call(destination: dst)
          else # cover
            processed = processor.resize_to_fill(width, height, gravity: "centre").convert("jpg").saver(quality: 85, interlace: true).call(destination: dst)
          end

          return success({ output_path: processed.to_s, width: width, height: height })
        rescue LoadError
          # fall through
        rescue StandardError => e
          StructuredLogger.warn(message: "vips_resize_failed", error: e.message, path: src_path.to_s) if defined?(StructuredLogger)
        end
      end

      cli = imagemagick_cli
      dst = ensure_ext(output_path.to_s, ".jpg")
      FileUtils.mkdir_p(File.dirname(dst))

      cmd = case fit
      when "contain"
        [ cli, src_path.to_s, "-auto-orient", "-resize", "#{width}x#{height}", dst ]
      when "fill"
        [ cli, src_path.to_s, "-auto-orient", "-resize", "#{width}x#{height}!", dst ]
      else # cover
        [ cli, src_path.to_s, "-auto-orient", "-resize", "#{width}x#{height}^", "-gravity", "center", "-extent", "#{width}x#{height}", dst ]
      end

      # Execute with array form to avoid shell interpolation
      ok = system(*cmd)
      return failure(StandardError.new("Resize failed"), metadata: { cmd: cmd.join(" ") }) unless ok
      success({ output_path: dst, width: width, height: height })
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :src_path, :output_path, :width, :height, :fit

    def use_vips?
      %w[1 true yes].include?(ENV["IMAGE_OPT_VIPS"].to_s.downcase)
    end

    def ensure_ext(dst, ext)
      File.extname(dst).downcase == ext ? dst : dst.sub(/\.[^.]+\z/, ext)
    end

    def imagemagick_cli
      override = ENV["IM_CLI"].to_s.strip
      return override if %w[magick convert].include?(override)
      system("magick -version > /dev/null 2>&1") ? "magick" : "convert"
    end
  end
end
