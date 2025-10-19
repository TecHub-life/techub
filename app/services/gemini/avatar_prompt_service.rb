module Gemini
  class AvatarPromptService < ApplicationService
    DEFAULT_STYLE_PROFILE = "cinematic tech illustration with abstract motifs; tasteful, modern, and legible without overbearing faces".freeze

    IMAGE_VARIANTS = {
      "1x1" => {
        aspect_ratio: "1:1",
        guidance: "Hero portrait framing, direct eye contact, luminous rim lighting, subtle circuit motifs."
      },
      "16x9" => {
        aspect_ratio: "16:9",
        guidance: "Layout-aware OG composition with strong negative space for overlays; visual motifs from profile data (languages as color ribbons, repos as constellations, activity as arcs). Optional small subject cameo only if avatar clearly depicts a human; keep off-center, low-contrast, and under 15% of frame. Strictly no text, watermarks, or logos."
      },
      "3x1" => {
        aspect_ratio: "3:1",
        guidance: "Ultra-wide banner with high-contrast yet unobtrusive abstract motifs; prioritize safe edges and central negative space for card UI. Use profile-inspired symbolism (language strands, repository nodes, subtle activity trails). Do not include faces or people. Absolutely no text or logos."
      },
      "9x16" => {
        aspect_ratio: "9:16",
        guidance: "Vertical supporting art with layered gradients and subtle geometric meshes; carry profile-inspired motifs tastefully. No text or logos; avoid literal portraits."
      }
    }.freeze

    FUN_STYLES = [
      { name: "anime", cue: "in vibrant anime character style, cel-shaded, expressive eyes, clean line art" },
      { name: "yellowtoon", cue: "in a yellow-skinned off-brand sitcom cartoon style, bold outlines, minimal shading" },
      { name: "macfarlane", cue: "in an off-brand cutaway-gag western animation style, flat colors, thick outlines" },
      { name: "multiverse", cue: "in a zany interdimensional science cartoon vibe, neon accents, surreal props" },
      { name: "pirate", cue: "as a whimsical pirate persona, tricorn hat, nautical motifs, parchment palette" }
    ].freeze

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
      prompts = add_fun_style_alternates(prompts, description, structured)

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
        hash[key] = build_variant_prompt(key, description, salient, variant, index.zero?)
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

    def build_variant_prompt(key, description, salient_details, variant, primary_variant)
      traits_line = salient_details.any? ? "Key visual traits: #{salient_details.join('; ')}." : ""
      profile_traits = include_profile_traits_line
      theme_line = prompt_theme.present? ? "Mood: #{prompt_theme}." : ""

      if key.to_s == "1x1"
        <<~PROMPT.squish
          Portrait prompt: #{primary_variant ? 'primary hero shot' : 'alternate framing'}.
          Subject description: #{description}
          #{traits_line}
          #{profile_traits}
          Visual guidance: Preserve the subject’s identity and key facial features. Maintain consistent skin tone, hair, and facial structure while allowing stylistic treatment. If the avatar is not a human photo, do not invent a realistic face—use emblematic or stylized representation instead.
          Visual style: #{style_profile}. #{theme_line}
          Composition (#{variant[:aspect_ratio]}): #{variant[:guidance]} Output aspect ratio: #{variant[:aspect_ratio]}.
        PROMPT
      else
        <<~PROMPT.squish
          Supporting artwork: Focus on abstract, illustrative, or symbolic visuals inspired by the avatar and profile context, not a literal recreation.
          Source avatar inspiration: #{description}
          #{traits_line}
          #{profile_traits}
          Constraints: no text or logos; keep safe edges for cropping and preserve clear negative space for UI overlays.
          If this is a 16:9 OG image, an optional small subject cameo is allowed only when the avatar clearly depicts a human; keep the figure subtle, off-center, and non-dominant. Otherwise depict no person and lean fully abstract.
          Visual style: #{style_profile}. #{theme_line}
          Composition (#{variant[:aspect_ratio]}): #{variant[:guidance]} Output aspect ratio: #{variant[:aspect_ratio]}.
        PROMPT
      end
    end

    # For 1x1, append a few fun alternates for generation variety
    def add_fun_style_alternates(prompts, description, structured)
      base = prompts.dup
      salient = structured_details(structured)
      base_1x1 = base["1x1"]
      return base unless base_1x1.present?

      FUN_STYLES.first(4).each_with_index do |style, idx|
        key = idx.zero? ? "1x1_alt" : "1x1_alt#{idx+1}"
        cue = style[:cue]
        base[key] = <<~PROMPT.squish
          Portrait prompt alternate: #{style[:name]}.
          Subject description: #{description}
          #{salient.any? ? "Key visual traits: #{salient.join('; ')}." : ""}
          Visual style: #{cue}. Keep identity consistent with source avatar; do not change skin tone or core features.
          Composition (1:1): #{IMAGE_VARIANTS["1x1"][:guidance]} Output aspect ratio: 1:1.
        PROMPT
      end
      base
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
      followers = profile_context[:followers_band]
      tenure = profile_context[:tenure_years]
      activity = profile_context[:activity_level]
      topics = Array(profile_context[:topics]).first(2)
      hireable = profile_context[:hireable] ? "yes" : nil

      parts = []
      parts << "languages: #{langs.join(', ')}" if langs.any?
      parts << "repos: #{repos.join(', ')}" if repos.any?
      parts << "orgs: #{orgs.join(', ')}" if orgs.any?
      parts << "followers: #{followers}" if followers.present?
      parts << "tenure: #{tenure}y" if tenure
      parts << "activity: #{activity}" if activity
      parts << "topics: #{topics.join(', ')}" if topics.any?
      parts << "hireable: #{hireable}" if hireable

      line = parts.join("; ")
      return "" if line.empty?

      capped = line[0, 120]
      "Profile traits (no text/logos): #{capped}."
    end
  end
end
