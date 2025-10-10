module Profiles
  class StoryFromProfile < ApplicationService
    MAX_OUTPUT_TOKENS = 600
    FALLBACK_MAX_TOKENS = 900
    TEMPERATURE = 0.65

    def initialize(login:, profile: nil)
      @login = login
      @profile = profile
    end

    def call
      record = profile || Profile.includes(:profile_repositories, :profile_organizations, :profile_social_accounts, :profile_languages)
        .find_by(login: login.downcase)
      return failure(StandardError.new("Profile not found for #{login}")) unless record

      context = build_context(record)
      prompt = build_prompt(context)

      client_result = Gemini::ClientService.call
      return client_result if client_result.failure?

      conn = client_result.value
      provider = Gemini::Configuration.provider

      primary_result = request_story(conn, provider, prompt, MAX_OUTPUT_TOKENS)
      return primary_result if primary_result.failure?

      story = primary_result.value[:story]
      finish_reason = primary_result.value[:finish_reason]
      metadata = primary_result.metadata.merge(prompt: prompt)

      if finish_reason == "MAX_TOKENS"
        fallback_result = request_story(conn, provider, prompt, FALLBACK_MAX_TOKENS)
        if fallback_result.success?
          story = fallback_result.value[:story]
          finish_reason = fallback_result.value[:finish_reason]
          metadata = fallback_result.metadata.merge(prompt: prompt, fallback_used: true, fallback_http_status: fallback_result.metadata[:http_status])
        else
          return fallback_result
        end
      end

      success(story, metadata: metadata.merge(finish_reason: finish_reason))
    rescue Faraday::Error => e
      failure(e)
    end

    private

    attr_reader :login, :profile

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

    def build_prompt(context)
      <<~PROMPT.squish
        Write an energetic micro-story (140-180 words) about #{context[:name]} (GitHub: #{context[:login]}).
        Celebrate their open-source adventures using these details:
        Summary: #{context[:summary].presence || "n/a"}.
        Favourite languages: #{context[:languages].presence&.join(", ") || "unknown"}.
        Notable repositories: #{context[:top_repositories].presence&.join(", ") || "none listed"}.
        Communities: #{context[:organizations].presence&.join(", ") || "independent"}.
        Social handles: #{context[:social_handles].presence&.join(", ") || "n/a"}.
        Keep the tone bright, weave in one surprising sci-fi or nautical twist, and end with a rallying tagline in quotes (max six words).
      PROMPT
    end

    def endpoint_path(provider)
      if provider == "ai_studio"
        "/v1beta/models/#{Gemini::Configuration.model}:generateContent"
      else
        project = Gemini::Configuration.project_id
        location = Gemini::Configuration.location
        "/v1/projects/#{project}/locations/#{location}/publishers/google/models/#{Gemini::Configuration.model}:generateContent"
      end
    end

    def build_payload(prompt, max_tokens)
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
          maxOutputTokens: max_tokens
        }
      }
    end

    def request_story(conn, provider, prompt, max_tokens)
      response = conn.post(endpoint_path(provider), build_payload(prompt, max_tokens))

      unless (200..299).include?(response.status)
        return failure(
          StandardError.new("Gemini story generation failed"),
          metadata: { http_status: response.status, body: response.body }
        )
      end

      story, finish_reason = extract_story(response.body)
      story = sanitize_story(story)

      if story.blank?
        return failure(
          StandardError.new("Gemini story response was empty"),
          metadata: { http_status: response.status, body: response.body }
        )
      end

      success(
        { story: story, finish_reason: finish_reason },
        metadata: { http_status: response.status, provider: provider, finish_reason: finish_reason }
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

    def extract_story(body)
      data = normalize_to_hash(body)
      return [ nil, nil ] unless data

      candidate = Array(dig_value(data, :candidates)).first
      return [ nil, nil ] unless candidate

      content = dig_value(candidate, :content)
      finish_reason = dig_value(candidate, :finishReason)
      return [ nil, finish_reason ] unless content

      parts = Array(dig_value(content, :parts))
      text = parts.filter_map { |part| dig_value(part, :text) }.join("\n").strip

      [ text, finish_reason ]
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

    def dig_value(source, key)
      return nil unless source.respond_to?(:[])

      source[key] || source[key.to_s]
    end

    def sanitize_story(text)
      return if text.blank?

      cleaned = text.to_s.gsub(/\s+/, " ").strip
      cleaned.empty? ? nil : cleaned
    end
  end
end
