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
      provider: nil,
      profile_context: nil, # optional: { name:, summary:, languages:[], top_repositories:[], organizations:[] }
      include_profile_traits: true
    )
      @avatar_path = avatar_path
      @prompt_theme = prompt_theme
      @style_profile = style_profile
      @description_service = description_service
      @provider_override = provider
      @profile_context = profile_context
      @include_profile_traits = include_profile_traits
    end

    def call
      description_result = description_service.call(
        avatar_path: avatar_path,
        provider: provider_override
      )

      description = nil
      structured = nil
      metadata = (description_result.metadata || {}).dup

      if description_result.success?
        raw_description = description_result.value
        structured = normalize_structured(description_result.metadata&.[](:structured)) ||
          parse_structured_from_string(raw_description)
        description = structured&.[]("description") || strip_json_artifacts(raw_description)
      end

      if weak_description?(description)
        if profile_context_present?
          description, structured = synthesize_from_profile(profile_context)
          metadata[:fallback_profile_used] = true if description.present?
        else
          # No profile context available; bubble the original failure if we have one
          return description_result.failure? ? description_result : failure(StandardError.new("Avatar description unavailable"), metadata: metadata)
        end
      end

      prompts = build_prompts(description, structured)

      success(
        {
          avatar_description: description,
          structured_description: structured,
          image_prompt: prompts["1x1"],
          image_prompts: prompts
        },
        metadata: metadata.merge(
          theme: prompt_theme,
          style_profile: style_profile
        )
      )
    end

    private

    attr_reader :avatar_path, :prompt_theme, :style_profile, :description_service, :provider_override, :profile_context

    def weak_description?(text)
      value = text.to_s.strip
      return true if value.empty?
      return true if value == "{" # incomplete JSON fragment seen in flaky outputs
      value.length < 12 # guard against too-short fragments
    end

    def profile_context_present?
      profile_context.is_a?(Hash) && profile_context.any?
    end

    def synthesize_from_profile(context)
      ctx = context.is_a?(Hash) ? context : {}
      name = ctx[:name].presence || "the developer"
      summary = ctx[:summary].to_s.strip
      langs = Array(ctx[:languages]).first(3).join(", ")
      repos = Array(ctx[:top_repositories]).first(2).join(", ")
      orgs = Array(ctx[:organizations]).first(2).join(", ")

      parts = []
      parts << summary if summary.present?
      parts << "Languages: #{langs}." if langs.present?
      parts << "Notable repos: #{repos}." if repos.present?
      parts << "Communities: #{orgs}." if orgs.present?

      synthesized = if parts.any?
        "Portrait of #{name}. #{parts.join(' ')}"
      else
        "Portrait of #{name}."
      end

      [ synthesized, { "description" => synthesized } ]
    end

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
      traits_line = salient_details.any? ? "Key visual traits: #{salient_details.join('; ')}." : ""
      profile_traits = include_profile_traits_line
      theme_line = prompt_theme.present? ? "Mood: #{prompt_theme}." : ""

      <<~PROMPT.squish
        Portrait prompt: #{primary_variant ? 'primary hero shot' : 'alternate framing'}.
        Subject description: #{description}
        #{traits_line}
        #{profile_traits}
        Visual style: #{style_profile}. #{theme_line}
        Composition (#{variant[:aspect_ratio]}): #{variant[:guidance]} Output aspect ratio: #{variant[:aspect_ratio]}.
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

    def include_profile_traits_line
      return "" unless @include_profile_traits && profile_context_present?

      # Non-visual, no text/logos: just semantic anchors for style; cap length
      langs = Array(profile_context[:languages]).first(3)
      repos = Array(profile_context[:top_repositories]).first(2)
      orgs = Array(profile_context[:organizations]).first(2)

      parts = []
      parts << "languages: #{langs.join(', ')}" if langs.any?
      parts << "repos: #{repos.join(', ')}" if repos.any?
      parts << "orgs: #{orgs.join(', ')}" if orgs.any?

      line = parts.join("; ")
      return "" if line.empty?

      capped = line[0, 120]
      "Profile traits (no text/logos): #{capped}."
    end
  end
end
