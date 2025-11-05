module Profiles
  class SynthesizeAiProfileService < ApplicationService
    include Gemini::ResponseHelpers
    include Gemini::SchemaHelpers

    MIN_TAGS = 6
    MAX_TAGS = 6
    TEMPERATURE = 0.7
    PROMPT_VERSION = "v1"
    FALLBACK_TAG_POOL = %w[
      coder builder open-source dev maker hacker engineer maintainer architect mentor tinkerer artisan strategist specialist
    ].freeze

    def initialize(profile:, overrides: nil, provider: nil)
      @profile = profile
      # Merge account-level overrides with any explicit overrides (explicit wins)
      base_overrides = Profiles::AiOverrides.for(profile)
      @overrides = base_overrides.merge((overrides || {}).transform_keys(&:to_sym))
      @provider_override = provider
    end

    def call
      return failure(StandardError.new("profile is required")) unless profile.is_a?(Profile)

      ctx = build_context(profile)
      provider = provider_override.presence || Gemini::Configuration.provider
      client_result = Gemini::ClientService.call(provider: provider)
      return client_result if client_result.failure?
      conn = client_result.value

      attempts = []

      # First attempt (creative within schema)
      resp = conn.post(
        Gemini::Endpoints.text_generate_path(
          provider: provider,
          model: Gemini::Configuration.model,
          project_id: Gemini::Configuration.project_id,
          location: Gemini::Configuration.location
        ),
        build_payload(ctx)
      )
      if (200..299).include?(resp.status)
        attempts << { http_status: resp.status, strict: false }
        preview = response_text_preview(resp.body)
      else
        preview = response_text_preview(resp.body)
        attempts << { http_status: resp.status, strict: false, error: true, preview: preview }
        metadata = ai_metadata(provider: provider, attempts: attempts, ctx: ctx, preview: preview).merge(
          http_status: resp.status,
          reason: "http_error",
          body_preview: resp.body.to_s[0, 500]
        )
        return failure(StandardError.new("Gemini AI traits request failed"), metadata: metadata)
      end
      json = extract_json_from_response(resp.body)
      cleaned = nil

      if json.blank?
        attempts.last[:empty] = true
        attempts.last[:preview] = preview if preview.present?
        if defined?(StructuredLogger)
          # Enhanced logging to debug extraction failure
          raw = normalize_to_hash(resp.body)
          candidates = Array(dig_value(raw, :candidates))
          first_candidate = candidates.first || {}
          content = dig_value(first_candidate, :content) || {}
          parts = Array(dig_value(content, :parts))
          texts = parts.filter_map { |p| dig_value(p, :text) }.join(" ").strip
          StructuredLogger.warn(
            message: "ai_traits_empty_response",
            login: profile.login,
            preview: preview,
            http_status: resp.status,
            parts_count: parts.length,
            text_length: texts.length,
            text_sample: texts[0, 100]
          )
        end
        # Try one strict re-ask before falling back
        resp_strict = conn.post(
          Gemini::Endpoints.text_generate_path(
            provider: provider,
            model: Gemini::Configuration.model,
            project_id: Gemini::Configuration.project_id,
            location: Gemini::Configuration.location
          ),
          build_payload(ctx, strict: true)
        )
        if (200..299).include?(resp_strict.status)
          attempts << { http_status: resp_strict.status, strict: true }
          json2 = extract_json_from_response(resp_strict.body)
          if json2.present?
            cleaned = validate_and_normalize(json2)
            if cleaned.blank? && defined?(StructuredLogger)
              StructuredLogger.warn(message: "validate_normalize_failed", login: profile.login, json2_keys: json2.keys.sort)
            end
          else
            attempts.last[:empty] = true
            attempts.last[:preview] = response_text_preview(resp_strict.body) if defined?(StructuredLogger)
          end
        else
          attempts << { http_status: resp_strict.status, strict: true, error: true }
          attempts.last[:preview] = response_text_preview(resp_strict.body)
        end

        if cleaned.blank?
          metadata = ai_metadata(provider: provider, attempts: attempts, ctx: ctx, preview: preview).merge(reason: "empty_response")
          return failure(StandardError.new("ai_traits_unavailable"), metadata: metadata)
        end
      else
        cleaned = validate_and_normalize(json)
      end
      # If initial cleaned output violates constraints, attempt a strict re-ask before falling back
      unless constraints_ok?(cleaned)
        # Strict re-ask with lower temperature and explicit correction guidance
        resp2 = conn.post(
          Gemini::Endpoints.text_generate_path(
            provider: provider,
            model: Gemini::Configuration.model,
            project_id: Gemini::Configuration.project_id,
            location: Gemini::Configuration.location
          ),
          build_payload(ctx, strict: true)
        )
        if (200..299).include?(resp2.status)
          attempts << { http_status: resp2.status, strict: true }
          json2 = extract_json_from_response(resp2.body)
          cleaned2 = validate_and_normalize(json2) if json2.present?
          cleaned = cleaned2 if cleaned2.present? && constraints_ok?(cleaned2)
        else
          attempts << { http_status: resp2.status, strict: true, error: true }
          attempts.last[:preview] = response_text_preview(resp2.body)
        end

        unless cleaned.present? && constraints_ok?(cleaned)
          metadata = ai_metadata(provider: provider, attempts: attempts, ctx: ctx, preview: preview).merge(reason: "constraints")
          return failure(StandardError.new("ai_traits_invalid"), metadata: metadata)
        end
      end

      unless cleaned.present?
        metadata = ai_metadata(provider: provider, attempts: attempts, ctx: ctx, preview: preview).merge(reason: "empty_output")
        return failure(StandardError.new("ai_traits_unavailable"), metadata: metadata)
      end

      # Final guardrails and overrides
      apply_overrides!(cleaned)
      cleaned["playing_card"] = fallback_playing_card(profile) unless playing_card_valid?(cleaned["playing_card"])

      # Persist to ProfileCard (concurrency-safe)
      # Ensure a single card per profile even when multiple jobs run concurrently
      begin
        record = ProfileCard.find_or_create_by(profile_id: profile.id) do |card|
          # Set default values when creating
          card.title = profile.display_name
          card.attack = 70
          card.defense = 60
          card.speed = 80
          card.tags = %w[coder developer maker builder engineer hacker]
        end
      rescue ActiveRecord::RecordNotUnique
        # Race condition: another job created the card between find and create
        # Just reload and use the existing one
        record = ProfileCard.find_by!(profile_id: profile.id)
      end

      record.assign_attributes(
        title: cleaned["title"].presence || profile.display_name,
        tagline: cleaned["tagline"].presence || cleaned["flavor_text"].presence || record.tagline,
        short_bio: cleaned["short_bio"],
        long_bio: cleaned["long_bio"],
        buff: cleaned["buff"],
        buff_description: cleaned["buff_description"],
        weakness: cleaned["weakness"],
        weakness_description: cleaned["weakness_description"],
        flavor_text: cleaned["flavor_text"],
        attack: cleaned["attack"],
        defense: cleaned["defense"],
        speed: cleaned["speed"],
        playing_card: cleaned["playing_card"],
        spirit_animal: cleaned["spirit_animal"],
        archetype: cleaned["archetype"],
        vibe: cleaned["vibe"],
        vibe_description: cleaned["vibe_description"],
        special_move: cleaned["special_move"],
        special_move_description: cleaned["special_move_description"],
        tags: cleaned["tags"],
        avatar_description: avatar_description_for(profile),
        ai_model: Gemini::Configuration.model,
        prompt_version: PROMPT_VERSION,
        generated_at: Time.current
      )

      unless record.save
        metadata = ai_metadata(provider: provider, attempts: attempts, ctx: ctx, preview: preview).merge(errors: record.errors.full_messages)
        return failure(StandardError.new("validation failed"), metadata: metadata)
      end

      StructuredLogger.info(message: "ai_traits_generated", login: profile.login, provider: provider, model: Gemini::Configuration.model, attempts: attempts) if defined?(StructuredLogger)
      success(record, metadata: ai_metadata(provider: provider, attempts: attempts, ctx: ctx, preview: preview))
    rescue Faraday::Error => e
      failure(e)
    end

    private

    attr_reader :profile, :overrides, :provider_override

    def ai_metadata(provider:, attempts:, ctx:, preview: nil)
      {
        provider: provider,
        attempts: attempts,
        model: Gemini::Configuration.model,
        prompt_version: PROMPT_VERSION,
        prompt: prompt_snapshot(ctx),
        response_preview: best_preview(preview, attempts)
      }.compact
    end

    def prompt_snapshot(ctx)
      {
        system_prompt: system_prompt,
        strict_system_prompt: strict_system_prompt,
        context: ctx
      }
    end

    def best_preview(primary, attempts)
      return primary if primary.present?

      Array(attempts).reverse_each do |attempt|
        candidate = attempt[:preview]
        return candidate if candidate.present?
      end
      nil
    end

    def log_service(status, error: nil, metadata: {})
      summary = if metadata.is_a?(Hash)
        metadata.slice(:provider, :model, :prompt_version, :reason)
      else
        {}
      end
      if metadata.is_a?(Hash) && metadata[:attempts].respond_to?(:size)
        summary[:attempt_count] = metadata[:attempts].size
      end
      super(status, error: error, metadata: summary.compact)
    end

    def build_context(record)
      {
        profile: {
          login: record.login,
          name: record.display_name,
          bio: record.bio,
          location: record.location,
          blog: record.blog,
          twitter_username: record.twitter_username,
          avatar_url: record.avatar_url,
          public_repos: record.public_repos,
          public_gists: record.public_gists,
          followers: record.followers,
          following: record.following
        },
        summary: record.summary,
        languages: language_ratios(record),
        social_accounts: Array(record.profile_social_accounts).map { |sa| { platform: sa.provider, handle: sa.display_name, url: sa.url } },
        organizations: Array(record.profile_organizations).map { |o| { login: o.login, name: (o.name.presence || o.login) } },
        top_repositories: repository_context(record, "top"),
        pinned_repositories: repository_context(record, "pinned"),
        active_repositories: repository_context_owned(record),
        recent_activity: record.profile_activity&.as_json,
        readme: { content: record.profile_readme&.content.to_s },
        avatar_description: record.profile_card&.avatar_description.to_s,
        overrides: overrides,
        allowed_spirit_animals: Motifs::Catalog.spirit_animal_names,
        allowed_archetypes: Motifs::Catalog.archetype_names
      }
    end

    def language_ratios(record)
      total = record.profile_languages.sum(:count)
      return [] if total.to_i <= 0
      record.profile_languages.order(count: :desc).limit(6).map do |lang|
        { name: lang.name, ratio: (lang.count.to_f / total).round(3) }
      end
    end

    def repository_context(record, type)
      Array(record.profile_repositories.where(repository_type: type)).map do |repo|
        owner_login = (repo.full_name.to_s.split("/").first.presence || record.login)
        {
          repo_full_name: repo.full_name || [ owner_login, repo.name ].compact.join("/"),
          owner_login: owner_login,
          description: repo.description,
          topics: Array(repo.repository_topics).map(&:name),
          language: repo.language,
          stars: repo.stargazers_count,
          forks: repo.forks_count,
          last_activity_at: repo.github_updated_at
        }
      end
    end

    def repository_context_owned(record)
      owners = Array(record.organization_logins).map(&:downcase) + [ record.login.downcase ]
      Array(record.profile_repositories.where(repository_type: "active")).select do |repo|
        (repo.full_name.to_s.split("/").first.presence || record.login).to_s.downcase.in?(owners)
      end.map do |repo|
        owner_login = (repo.full_name.to_s.split("/").first.presence || record.login)
        {
          repo_full_name: repo.full_name || [ owner_login, repo.name ].compact.join("/"),
          owner_login: owner_login,
          description: repo.description,
          topics: Array(repo.repository_topics).map(&:name),
          language: repo.language,
          stars: repo.stargazers_count,
          forks: repo.forks_count,
          last_activity_at: repo.github_updated_at
        }
      end
    end

    def build_payload(ctx, strict: false)
      instruction = strict ? strict_system_prompt : system_prompt
      temp = strict ? 0.25 : TEMPERATURE
      provider = provider_override.presence || Gemini::Configuration.provider

      adapter = Gemini::Providers::Adapter.for(provider)
      sys = adapter.system_instruction_hash(instruction)
      contents = adapter.contents_for_text(ctx.to_json)
      schema = response_schema_for(provider == "vertex" ? "vertex" : "ai_studio")
      gen_cfg = adapter.generation_config_hash(
        temperature: temp,
        max_tokens: 2300,
        schema: schema,
        structured_json: true
      )
      adapter.envelope(contents: contents, generation_config: gen_cfg, system_instruction: sys)
    end

    def system_prompt
      <<~PROMPT.squish
        You create engaging, third-person developer profiles grounded in provided public data. Follow the constraints exactly.
        Only include repositories owned by the user or organizations they belong to. Do not claim employment. Apply overrides as given.
        Provide:
        - title: 2–5 word heroic codename capturing their archetype.
        - tagline: 1-sentence hook (max 16 words) distinct from flavor_text.
        - flavor_text: a punchy quote-style line (max 80 chars).
        Choose attack/defense/speed as integers in 60–99, scaled by signals:
        - Attack: followers, repo stars, active repos.
        - Defense: account age, org count, public repos, testing/tooling cues.
        - Speed: recent activity volume and recency.
        Pick playing_card from a standard 52-card deck formatted '<Rank> of <SuitSymbol>' using suits ♣ ♦ ♥ ♠.
        When allowlists are provided for spirit_animal/archetype, pick from those; otherwise choose reasonable options. Output valid JSON matching the provided schema.
        Reply with JSON only.
      PROMPT
    end

    def strict_system_prompt
      <<~PROMPT.squish
        STRICT RE-ASK: The previous output violated constraints. Produce valid JSON matching the schema with:
        - title: 2–5 word codename in Title Case.
        - tagline: <=16 words, distinct from flavor_text.
        - tags: exactly 6 items, lowercase kebab-case (1–3 words), unique.
        - attack/defense/speed: integers 60–99.
        - playing_card: exactly one of 52 cards, formatted '<Rank> of <SuitSymbol>' using suits ♣ ♦ ♥ ♠.
        - spirit_animal/archetype: choose ONLY from provided allowlists.
        Keep third-person voice; no emojis; ground claims. JSON only.
      PROMPT
    end

    def response_schema_for(provider)
      base = {
        type: "object",
        properties: {
          title: { type: "string" },
          tagline: { type: "string" },
          short_bio: { type: "string" },
          long_bio: { type: "string" },
          buff: { type: "string" },
          buff_description: { type: "string" },
          weakness: { type: "string" },
          weakness_description: { type: "string" },
          vibe: { type: "string" },
          vibe_description: { type: "string" },
          special_move: { type: "string" },
          special_move_description: { type: "string" },
          flavor_text: { type: "string" },
          tags: { type: "array", items: { type: "string" } },
          attack: { type: "integer" },
          defense: { type: "integer" },
          speed: { type: "integer" },
          playing_card: { type: "string" },
          spirit_animal: { type: "string" },
          archetype: { type: "string" }
        },
        required: %w[title tagline short_bio long_bio buff buff_description weakness weakness_description vibe vibe_description special_move special_move_description flavor_text tags attack defense speed playing_card spirit_animal archetype]
      }

      # "propertyOrdering" is a non-standard extension that some providers ignore.
      # Keep it for AI Studio where it's tolerated; omit for Vertex to avoid 400s.
      if provider != "vertex"
        base[:propertyOrdering] = %w[title tagline short_bio long_bio buff buff_description weakness weakness_description vibe vibe_description special_move special_move_description flavor_text tags attack defense speed playing_card spirit_animal archetype]
      end

      base
    end

    def extract_structured_json(parts)
      Array(parts).each do |part|
        part_hash = part.is_a?(Hash) ? part : part.to_h rescue {}
        struct = dig_value(part_hash, :structValue) || dig_value(part_hash, :struct_value) || dig_value(part_hash, :jsonValue) || dig_value(part_hash, :json_value)
        next unless struct.present?
        return struct if struct.is_a?(Hash)
      end
      nil
    end

    def extract_json_from_response(body)
      raw = normalize_to_hash(body)
      # Safely navigate candidates → content → parts without wrapping hashes in arrays incorrectly
      candidates = Array(dig_value(raw, :candidates))
      first_candidate = candidates.first || {}
      content = dig_value(first_candidate, :content) || {}
      parts = dig_value(content, :parts)

      # Handle case where parts is not an array
      parts = [ parts ] if parts.is_a?(Hash)
      parts = [] if parts.nil?

      # First, prefer function-call structured output when present
      Array(parts).each do |part|
        fc = dig_value(part, :functionCall) || dig_value(part, :function_call)
        next unless fc
        args = dig_value(fc, :args) || dig_value(fc, :arguments)
        if args.is_a?(Hash)
          return args
        elsif args.is_a?(String)
          parsed = parse_relaxed_json(args)
          return parsed if parsed.is_a?(Hash)
        end
      end

      json = extract_structured_json(parts)
      texts = Array(parts).filter_map { |p| dig_value(p, :text) }.join(" ").strip

      # Try parsing the text as JSON if no structured response found
      if json.blank? && texts.present?
        json = parse_relaxed_json(texts)
        # If still blank, log for debugging
        if json.blank? && defined?(StructuredLogger)
          StructuredLogger.debug(message: "json_extraction_failed", text_preview: texts[0, 200], parts_count: Array(parts).length)
        end
      end

      json
    end

    def response_text_preview(body, limit: 300)
      raw = normalize_to_hash(body)
      candidates = Array(dig_value(raw, :candidates))
      first_candidate = candidates.first || {}
      content = dig_value(first_candidate, :content) || {}
      parts = Array(dig_value(content, :parts))
      text = parts.filter_map { |p| dig_value(p, :text) }.join(" ").to_s.strip
      return nil if text.blank?
      text.length > limit ? "#{text[0, limit]}..." : text
    rescue StandardError
      nil
    end

    def validate_and_normalize(h)
      return nil unless h.is_a?(Hash)

      out = h.transform_keys(&:to_s)
      out["title"] = title_cap(out["title"].to_s.strip.first(60))
      out["tagline"] = out["tagline"].to_s.strip.first(140)
      # Enforce ranges
      %w[attack defense speed].each do |k|
        out[k] = out[k].to_i
        out[k] = 60 if out[k] < 60
        out[k] = 99 if out[k] > 99
      end
      # Normalize tags
      tags = Array(out["tags"]).map { |t| normalize_tag(t) }.reject(&:blank?).uniq
      tags = tags.first(MAX_TAGS)
      if tags.length < MIN_TAGS
        fallback_cycle = FALLBACK_TAG_POOL.cycle
        while tags.length < MIN_TAGS
          candidate = fallback_cycle.next
          next if candidate.blank? || tags.include?(candidate)
          tags << candidate
        end
      end
      out["tags"] = tags.first(MAX_TAGS)
      # Clamp lengths where necessary
      out["flavor_text"] = out["flavor_text"].to_s.strip.first(80)
      out["buff"] = title_cap(out["buff"].to_s.strip.first(30))
      out["weakness"] = title_cap(out["weakness"].to_s.strip.first(30))
      out["vibe"] = title_cap(out["vibe"].to_s.strip.first(30))
      out["special_move"] = title_cap(out["special_move"].to_s.strip.first(40))
      out
    end

    def constraints_ok?(out)
      return false unless out.is_a?(Hash)
      return false unless playing_card_valid?(out["playing_card"])
      tags = Array(out["tags"]).compact
      return false unless tags.length == 6 && tags.all? { |t| t =~ /\A[a-z0-9]+(?:-[a-z0-9]+){0,2}\z/ }
      %w[attack defense speed].all? { |k| out[k].to_i.between?(60, 99) }
    end

    def playing_card_valid?(val)
      !!(val.to_s =~ /\A(Ace|[2-9]|10|Jack|Queen|King) of [♣♦♥♠]\z/)
    end

    def apply_overrides!(out)
      return out if overrides.blank?
      %w[attack defense speed playing_card spirit_animal archetype].each do |k|
        out[k] = overrides[k.to_sym] if overrides.key?(k.to_sym)
        out[k] = overrides[k] if overrides.key?(k)
      end
      out
    end

    def normalize_tag(t)
      s = t.to_s.downcase.strip
      s = s.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-")
      s.presence
    end

    def fallback_tag
      FALLBACK_TAG_POOL.sample
    end

    def fallback_playing_card(record)
      # Suit by dominant language; rank by followers/star sum
      lang = record.profile_languages.order(count: :desc).first&.name.to_s.downcase
      suit = case lang
      when /ruby|rails/ then "♥"
      when /js|ts|node/ then "♣"
      when /go/ then "♠"
      when /python/ then "♦"
      else [ "♣", "♦", "♥", "♠" ][record.login.to_s.hash % 4]
      end
      star_sum = Array(record.top_repositories).first(5).sum { |r| r.stargazers_count.to_i }
      score = (record.followers.to_i / 250) + (star_sum / 1000)
      rank = case score
      when 8.. then "Ace"
      when 6..7 then "King"
      when 4..5 then "Queen"
      when 2..3 then "Jack"
      else [ "10", "9", "8", "7" ][record.public_repos.to_i % 4]
      end
      "#{rank} of #{suit}"
    end

    def title_cap(s)
      s.split.map { |w| w[0]&.upcase.to_s + w[1..] }.join(" ")
    end

    def avatar_description_for(record)
      # Use existing if available; otherwise try to generate quickly (best effort)
      return record.profile_card.avatar_description if record.profile_card&.avatar_description.present?
      avatar_path = record.avatar_url
      result = Gemini::ImageDescriptionService.call(image_path: avatar_path) rescue nil
      result&.success? ? result.value : nil
    end
  end
end
