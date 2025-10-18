module Profiles
  class StoryFromProfile < ApplicationService
    include Gemini::ResponseHelpers
    TOKEN_STEPS = [ 900, 1300, 1700, 2100, 2500, 2900 ].freeze
    TOKEN_INCREMENT = 400
    MAX_TOKEN_LIMIT = 4_100
    TEMPERATURE = 0.65

    def initialize(login:, profile: nil, provider: nil)
      @login = login
      @profile = profile
      @provider_override = provider
    end

    def call
      record = profile || Profile.includes(:profile_repositories, :profile_organizations, :profile_social_accounts, :profile_languages)
        .find_by(login: login.downcase)
      return failure(StandardError.new("Profile not found for #{login}")) unless record

      context = build_context(record)
      prompt = build_prompt(context)

      provider = story_provider
      generation_result = generate_story_with_provider(provider, prompt)
      return generation_result if generation_result.success?

      error = generation_result.error || StandardError.new("Gemini story generation failed")
      metadata = (generation_result.metadata || {}).merge(provider: provider, prompt: prompt)

      failure(error, metadata: metadata)
    rescue Faraday::Error => e
      failure(e)
    end

    private

    attr_reader :login, :profile, :provider_override

    def build_context(record)
      {
        name: record.respond_to?(:name) ? (record.name.presence || record.login) : record.login,
        summary: record.respond_to?(:summary) ? record.summary.to_s.strip : "",
        languages: language_names(record),
        top_repositories: repository_names(record),
        organizations: organization_names(record),
        social_handles: social_names(record),
        login: record.login
      }
    end

    def story_provider
      provider_override.presence || Gemini::Configuration.provider
    end

    def generate_story_with_provider(provider, prompt)
      client_result = Gemini::ClientService.call(provider: provider)
      return client_result if client_result.failure?

      conn = client_result.value

      attempts = []
      story_payload = nil

      token_limits = TOKEN_STEPS.dup
      attempt_index = 0

      while attempt_index < token_limits.length
        token_limit = token_limits[attempt_index]

        attempt_result = request_story(conn, provider, prompt, token_limit, attempt_index)
        return attempt_result if attempt_result.failure?

        attempts << attempt_result.metadata.merge(limit: token_limit)
        story_payload = attempt_result.value
        attempt_index += 1

        if story_payload[:partial]
          if token_limits.length == attempt_index && token_limit < MAX_TOKEN_LIMIT
            next_limit = [ token_limit + TOKEN_INCREMENT, MAX_TOKEN_LIMIT ].min
            token_limits << next_limit if next_limit > token_limit
          end
          next
        end

        break unless story_payload[:finish_reason] == "MAX_TOKENS" || story_payload[:story].to_s.split.size < 130
      end

      if story_payload.nil? || story_payload[:story].blank?
        return failure(
          StandardError.new("Gemini story response was empty"),
          metadata: {
            provider: provider,
            prompt: prompt,
            attempts: attempts
          }
        )
      end

      story_output = format_story_output(story_payload)
      metadata = {
        provider: story_payload[:provider],
        prompt: prompt,
        finish_reason: story_payload[:finish_reason],
        attempts: attempts
      }

      success(story_output, metadata: metadata)
    rescue Faraday::Error => e
      failure(e)
    end

    def build_prompt(context)
      <<~PROMPT.squish
        You are writing a celebratory 140-180 word micro-story about #{context[:name]} (GitHub: #{context[:login]}).
        Facts to weave in naturally:
        - Summary: #{context[:summary].presence || "n/a"}
        - Favourite languages: #{context[:languages].presence&.join(", ") || "unknown"}
        - Notable repositories: #{context[:top_repositories].presence&.join(", ") || "none listed"}
        - Communities: #{context[:organizations].presence&.join(", ") || "independent"}
        - Social handles: #{context[:social_handles].presence&.join(", ") || "n/a"}
        Style guidelines:
        - Three lively paragraphs: origin spark, present-day impact, playful future.
        - Include one surprising sci-fi or nautical twist grounded in their work.
        - End with a rallying tagline (2-6 words) in double quotes on a new line.
        Respond as JSON with keys `story` (full paragraphs) and `tagline` (without surrounding punctuation except quotes).
      PROMPT
    end

    # endpoint computed via Gemini::Endpoints

    def build_payload(prompt, max_tokens)
      provider = story_provider
      schema = {
        type: "object",
        properties: {
          story: { type: "string" },
          tagline: { type: "string" }
        },
        required: %w[story tagline]
      }

      if provider == "vertex"
        {
          contents: [
            {
              role: "user",
              parts: [
                { text: prompt }
              ]
            }
          ],
          generation_config: {
            temperature: TEMPERATURE,
            max_output_tokens: max_tokens,
            response_mime_type: "application/json",
            response_schema: schema
          }
        }
      else
        {
          contents: [
            {
              role: "user",
              parts: [
                { text: prompt }
              ]
            }
          ],
          generationConfig: {
            temperature: TEMPERATURE,
            maxOutputTokens: max_tokens,
            responseMimeType: "application/json",
            responseSchema: schema
          }
        }
      end
    end

    def request_story(conn, provider, prompt, max_tokens, attempt_index)
      response = conn.post(
        Gemini::Endpoints.text_generate_path(
          provider: provider,
          model: Gemini::Configuration.model,
          project_id: Gemini::Configuration.project_id,
          location: Gemini::Configuration.location
        ),
        build_payload(prompt, max_tokens)
      )

      unless (200..299).include?(response.status)
        return failure(
          StandardError.new("Gemini story generation failed"),
          metadata: { http_status: response.status, body: response.body, attempt: attempt_index }
        )
      end

      payload = extract_story_payload(response.body)
      story_blank = payload[:story].blank?
      finish_reason = payload[:finish_reason]

      if story_blank && finish_reason != "MAX_TOKENS"
        return failure(
          StandardError.new("Gemini story response was empty"),
          metadata: { http_status: response.status, body: response.body, attempt: attempt_index }
        )
      end

      success(
        payload.merge(provider: provider, partial: (finish_reason == "MAX_TOKENS") || story_blank),
        metadata: { http_status: response.status, provider: provider, finish_reason: finish_reason, attempt: attempt_index, partial: (finish_reason == "MAX_TOKENS") || story_blank }
      )
    end

    def language_names(record)
      collection = record.respond_to?(:profile_languages) ? record.profile_languages : []
      if collection.respond_to?(:order)
        collection.order(count: :desc).limit(5).pluck(:name).map(&:to_s)
      else
        Array(collection)
          .sort_by { |lang| -(lang.respond_to?(:count) ? lang.count.to_i : 0) }
          .first(5)
          .map { |lang| fetch_attr(lang, :name) }
      end
    end

    def repository_names(record)
      collection = record.respond_to?(:profile_repositories) ? record.profile_repositories : []
      if collection.respond_to?(:where)
        collection.where(repository_type: "top").order(stargazers_count: :desc).limit(3).pluck(:name)
      else
        Array(collection)
          .select { |repo| fetch_attr(repo, :repository_type) == "top" }
          .sort_by { |repo| -fetch_attr(repo, :stargazers_count).to_i }
          .first(3)
          .map { |repo| fetch_attr(repo, :name) }
      end
    end

    def organization_names(record)
      collection = record.respond_to?(:profile_organizations) ? record.profile_organizations : []
      if collection.respond_to?(:limit)
        collection.limit(3).pluck(:name, :login).map { |name, login| name.presence || login }
      else
        Array(collection).first(3).map { |org| fetch_attr(org, :name).presence || fetch_attr(org, :login) }
      end
    end

    def social_names(record)
      collection = record.respond_to?(:profile_social_accounts) ? record.profile_social_accounts : []
      if collection.respond_to?(:limit)
        collection.limit(3).pluck(:display_name, :provider).map { |display_name, provider| display_name.presence || provider }
      else
        Array(collection).first(3).map { |acc| fetch_attr(acc, :display_name).presence || fetch_attr(acc, :provider) }
      end
    end

    def fetch_attr(object, key)
      return "" unless object

      if object.respond_to?(key)
        object.public_send(key)
      elsif object.respond_to?(:[])
        object[key.to_s] || object[key.to_sym]
      end
    end

    def extract_story_payload(body)
      data = normalize_to_hash(body)
      return { story: nil, tagline: nil, finish_reason: nil } unless data

      candidate = Array(dig_value(data, :candidates)).first
      finish_reason = dig_value(candidate, :finishReason)

      structured_content = dig_value(candidate, :content)
      parts = Array(dig_value(structured_content, :parts))

      # Join all text parts together; some providers emit multiple parts
      raw_text = parts.filter_map { |part| dig_value(part, :text) }.join

      # First attempt: strict/relaxed JSON parse
      parsed = normalize_to_hash(raw_text) || parse_relaxed_json(raw_text) || {}

      story = sanitize_story(parsed["story"])
      tagline = parsed["tagline"]

      # Fallback: provider ignored schema and returned plain text paragraphs
      if story.blank?
        fallback_story, fallback_tagline = split_story_and_tagline_from_text(raw_text)
        story = sanitize_story(fallback_story)
        tagline ||= fallback_tagline
      end

      {
        story: story,
        tagline: tagline,
        finish_reason: finish_reason,
        provider: nil
      }
    end

    def normalize_to_hash(body)
      return body if body.is_a?(Hash)

      if body.respond_to?(:to_hash)
        body.to_hash
      elsif body.present?
        JSON.parse(body)
      end
    rescue JSON::ParserError
      nil
    end

    def parse_relaxed_json(text)
      value = text.to_s
      return nil if value.strip.empty?

      begin
        return JSON.parse(value)
      rescue JSON::ParserError
        # try stripped trailing commas in objects/arrays
      end

      begin
        cleaned = value.gsub(/,\s*(?=[}\]])/, "")
        return JSON.parse(cleaned)
      rescue JSON::ParserError
        # try fenced code block
      end

      if value =~ /```(?:json)?\s*([\s\S]*?)\s*```/i
        fenced = $1
        begin
          return JSON.parse(fenced)
        rescue JSON::ParserError
          # ignore and fall through
        end
      end

      nil
    end

    def dig_value(source, key)
      return nil unless source.respond_to?(:[])

      source[key] || source[key.to_s]
    end

    def sanitize_story(text)
      return if text.blank?

      cleaned = text.to_s.strip
      cleaned.empty? ? nil : cleaned
    end

    def split_story_and_tagline_from_text(text)
      value = text.to_s.strip
      return [ nil, nil ] if value.empty?

      # Prefer a trailing quoted line as tagline
      if value =~ /\n\s*"([^"]{4,200})"\s*\z/
        tagline = $1
        story_text = value.sub(/\n\s*"([^"]{4,200})"\s*\z/, "").strip
        return [ story_text, tagline ]
      end

      # If the model returned JSON-looking text without quotes, keep as story
      [ value, nil ]
    end
    def format_story_output(payload)
      return "" unless payload

      story = payload[:story].to_s.strip
      tagline = payload[:tagline].to_s.strip

      return story if tagline.blank?

      normalized_tagline = tagline.delete_prefix('"').delete_suffix('"')
      tagged_story = story.end_with?("\n") ? story : "#{story}\n"
      %(#{tagged_story}\n"#{normalized_tagline}")
    end
  end
end
