module Profiles
  class StoryFromProfile < ApplicationService
    MAX_OUTPUT_TOKENS = 400
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
      response = conn.post(endpoint_path(provider), build_payload(prompt))

      unless (200..299).include?(response.status)
        return failure(StandardError.new("Gemini story generation failed"), metadata: { http_status: response.status, body: response.body })
      end

      story = extract_story(response.body)&.strip
      return failure(StandardError.new("Gemini story response was empty"), metadata: { body: response.body }) if story.blank?

      success(story, metadata: {
        http_status: response.status,
        provider: provider,
        prompt: prompt
      })
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
        Write a playful 120-word micro-story about #{context[:name]} (GitHub: #{context[:login]}).
        Celebrate their open-source adventures using these details:
        Summary: #{context[:summary].presence || "n/a"}.
        Favourite languages: #{context[:languages].presence&.join(", ") || "unknown"}.
        Notable repositories: #{context[:top_repositories].presence&.join(", ") || "none listed"}.
        Communities: #{context[:organizations].presence&.join(", ") || "independent"}.
        Social handles: #{context[:social_handles].presence&.join(", ") || "n/a"}.
        Keep the tone bright, include one surprising twist, and finish with a short rallying tagline in quotes.
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

    def build_payload(prompt)
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
          maxOutputTokens: MAX_OUTPUT_TOKENS
        }
      }
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
      return unless data

      candidate = Array(dig_value(data, :candidates)).first
      return unless candidate

      content = dig_value(candidate, :content)
      return unless content

      parts = Array(dig_value(content, :parts))
      parts.filter_map { |part| dig_value(part, :text) }.join("\n").strip
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
  end
end
