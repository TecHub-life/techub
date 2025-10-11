module Profiles
  class GeneratePipelineService < ApplicationService
    VARIANTS = %w[og card simple].freeze

    def initialize(login:, host: nil, provider: nil, upload: nil, optimize: true)
      @login = login.to_s.downcase
      @host = host.presence || ENV["APP_HOST"].presence || "http://127.0.0.1:3000"
      @provider = provider # nil respects default
      @upload = upload.nil? ? ENV["GENERATED_IMAGE_UPLOAD"].to_s.downcase.in?([ "1", "true", "yes" ]) : upload
      @optimize = optimize
    end

    def call
      return failure(StandardError.new("login required")) if login.blank?

      # 1) Ensure profile + avatar exists
      sync = Profiles::SyncFromGithub.call(login: login)
      return sync if sync.failure?
      profile = sync.value

      # 2) Generate AI images (prompts + 4 variants);
      images = Gemini::AvatarImageSuiteService.call(
        login: login,
        provider: provider,
        filename_suffix: provider,
        output_dir: Rails.root.join("public", "generated")
      )
      return images if images.failure?

      # 3) Synthesize card attributes and persist
      synth = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
      return synth if synth.failure?

      # 4) Capture screenshots (OG/card/simple)
      captures = {}
      VARIANTS.each do |variant|
        shot = Screenshots::CaptureCardService.call(login: login, variant: variant, host: host)
        return shot if shot.failure?
        captures[variant] = shot.value

        # Optional post-process optimization
        if optimize
          fmt = variant == "og" ? nil : nil # keep defaults; project policy can adjust
          Images::OptimizeService.call(path: shot.value[:output_path], output_path: shot.value[:output_path], format: fmt)
        end
      end

      success(
        {
          login: login,
          images: images.value,
          screenshots: captures,
          card_id: synth.value.id
        },
        metadata: { login: login, provider: provider, upload: upload, optimize: optimize }
      )
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :login, :host, :provider, :upload, :optimize
  end
end
