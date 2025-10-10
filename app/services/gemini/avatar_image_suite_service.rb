module Gemini
  class AvatarImageSuiteService < ApplicationService
    VARIANTS = {
      "1x1" => { aspect_ratio: "1:1", filename: "avatar-1x1.png" },
      "16x9" => { aspect_ratio: "16:9", filename: "avatar-16x9.png" },
      "3x1" => { aspect_ratio: "3:1", filename: "avatar-3x1.png" },
      "9x16" => { aspect_ratio: "9:16", filename: "avatar-9x16.png" }
    }.freeze

    def initialize(
      login:,
      avatar_path: nil,
      output_dir: Rails.root.join("public", "generated"),
      prompt_theme: "TecHub",
      style_profile: AvatarPromptService::DEFAULT_STYLE_PROFILE,
      prompt_service: AvatarPromptService,
      image_service: ImageGenerationService
    )
      @login = login
      @avatar_path = avatar_path
      @output_dir = Pathname.new(output_dir)
      @prompt_theme = prompt_theme
      @style_profile = style_profile
      @prompt_service = prompt_service
      @image_service = image_service
    end

    def call
      description_path = source_avatar_path
      return failure(StandardError.new("Avatar image not found for #{login}"), metadata: { expected_path: description_path.to_s }) unless File.exist?(description_path)

      prompts_result = prompt_service.call(
        avatar_path: description_path,
        prompt_theme: prompt_theme,
        style_profile: style_profile
      )
      return prompts_result if prompts_result.failure?

      description = prompts_result.value[:avatar_description]
      prompts = prompts_result.value[:image_prompts]

      generated = {}

      VARIANTS.each do |key, variant|
        prompt = prompts[key]
        unless prompt.present?
          return failure(StandardError.new("Missing prompt for #{key} variant"), metadata: { prompts: prompts.keys })
        end

        variant_output_path = output_dir.join(login, variant[:filename])
        result = image_service.call(
          prompt: prompt,
          aspect_ratio: variant[:aspect_ratio],
          output_path: variant_output_path
        )
        return result if result.failure?

        generated[key] = result.value.merge(aspect_ratio: variant[:aspect_ratio])
      end

      success(
        {
          login: login,
          avatar_description: description,
          prompts: prompts,
          images: generated,
          output_dir: output_dir.join(login).to_s
        },
        metadata: prompts_result.metadata
      )
    end

    private

    attr_reader :login, :avatar_path, :output_dir, :prompt_theme, :style_profile, :prompt_service, :image_service

    def source_avatar_path
      return Pathname.new(avatar_path) if avatar_path.present?

      Rails.root.join("public", "avatars", "#{login}.png")
    end
  end
end
