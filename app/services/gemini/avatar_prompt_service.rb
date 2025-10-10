module Gemini
  class AvatarPromptService < ApplicationService
    DEFAULT_STYLE_PROFILE = "neon-lit anime portrait with confident tech leader energy".freeze

    IMAGE_VARIANTS = {
      "1x1" => {
        aspect_ratio: "1:1",
        guidance: "Hero portrait framing, direct eye contact, luminous rim lighting, subtle circuit motifs."
      },
      "16x9" => {
        aspect_ratio: "16:9",
        guidance: "Cinematic waist-up view in a futuristic control space with ambient glow and interface panels."
      },
      "3x1" => {
        aspect_ratio: "3:1",
        guidance: "Ultra-wide sweep with the subject guiding flowing light trails across a skyline."
      },
      "9x16" => {
        aspect_ratio: "9:16",
        guidance: "Poster-style vertical composition with dynamic stance and spotlight halo."
      }
    }.freeze

    def initialize(
      avatar_path:,
      prompt_theme: "TecHub",
      style_profile: DEFAULT_STYLE_PROFILE,
      description_service: Gemini::AvatarDescriptionService,
      provider: nil
    )
      @avatar_path = avatar_path
      @prompt_theme = prompt_theme
      @style_profile = style_profile
      @description_service = description_service
      @provider_override = provider
    end

    def call
      description_result = description_service.call(
        avatar_path: avatar_path,
        provider: provider_override
      )
      return description_result if description_result.failure?

      raw_description = description_result.value
      structured = normalize_structured(description_result.metadata&.[](:structured)) ||
        parse_structured_from_string(raw_description)
      description = structured&.[]("description") || strip_json_artifacts(raw_description)

      prompts = build_prompts(description, structured)

      success(
        {
          avatar_description: description,
          structured_description: structured,
          image_prompt: prompts["1x1"],
          image_prompts: prompts
        },
        metadata: (description_result.metadata || {}).merge(
          theme: prompt_theme,
          style_profile: style_profile
        )
      )
    end

    private

    attr_reader :avatar_path, :prompt_theme, :style_profile, :description_service, :provider_override

    def build_prompts(description, structured)
      salient = structured_details(structured)

      IMAGE_VARIANTS.each_with_index.each_with_object({}) do |((key, variant), index), hash|
        hash[key] = build_variant_prompt(description, salient, variant, index.zero?)
      end
    end

    def structured_details(structured)
      return [] unless structured.is_a?(Hash)

      details = []
      %w[facial_features expression attire palette background mood].each do |key|
        value = structured[key] || structured[key.to_sym]
        details << "#{key.tr('_', ' ')}: #{value}" if value.present?
      end
      details
    end

    def build_variant_prompt(description, salient_details, variant, primary_variant)
      traits_line = salient_details.any? ? "Key traits: #{salient_details.join('; ')}." : ""
      theme_line = prompt_theme.present? ? "Mood: #{prompt_theme}." : ""

      <<~PROMPT.squish
        Portrait prompt: #{primary_variant ? 'primary hero shot' : 'alternate framing'}.
        Subject description: #{description}
        #{traits_line}
        Visual style: #{style_profile}. #{theme_line}
        Composition (#{variant[:aspect_ratio]}): #{variant[:guidance]}
      PROMPT
    end

    def normalize_structured(structured)
      return unless structured.is_a?(Hash)

      structured.each_with_object({}) do |(key, value), acc|
        acc[key.to_s] = value.is_a?(String) ? value.strip : value
      end
    end

    def parse_structured_from_string(raw_description)
      return unless raw_description.is_a?(String) && raw_description.strip.start_with?("{")

      json = parse_relaxed_json(raw_description)
      normalize_structured(json) if json.is_a?(Hash) && json["description"].present?
    rescue JSON::ParserError
      nil
    end

    def strip_json_artifacts(text)
      return "" if text.nil?

      value = text.to_s.strip
      return value unless value.start_with?("{") && value.include?("}")

      attempt = parse_structured_from_string(value)
      return attempt["description"] if attempt

      cleaned = value.gsub(/\{.*\}/m, "").strip
      cleaned.empty? ? value : cleaned
    end

    def parse_relaxed_json(text)
      JSON.parse(text.to_s)
    rescue JSON::ParserError
      cleaned = text.to_s.gsub(/,\s*(?=[}\]])/, "")
      JSON.parse(cleaned)
    end
  end
end
