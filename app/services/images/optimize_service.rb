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
        # In tests, avoid invoking external commands
        FileUtils.cp(path, output_path) unless output_path == path
        return success({ output_path: output_path.to_s, format: effective_format, quality: quality })
      end

      cmd = build_command
      ok = system(*cmd)
      return failure(StandardError.new("Image optimization failed"), metadata: { cmd: cmd.join(" ") }) unless ok

      success({ output_path: output_path.to_s, format: effective_format, quality: quality })
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :path, :output_path, :format, :quality

    def build_command
      # Use ImageMagick convert via `magick` CLI
      src = path.to_s
      dst = output_path.to_s
      case effective_format
      when "jpg", "jpeg"
        [ "magick", src, "-strip", "-interlace", "Plane", "-quality", quality.to_s, ensure_ext(dst, ".jpg") ]
      else # png
        [ "magick", src, "-strip", "-define", "png:compression-level=9", ensure_ext(dst, ".png") ]
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
  end
end
