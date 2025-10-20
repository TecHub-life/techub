require "json"
module Motifs
  class GenerateLoreService < ApplicationService
    def initialize(name:, description:)
      @name = name.to_s
      @description = description.to_s
    end

    def call
      provider = Gemini::Configuration.provider
      client = Gemini::ClientService.call(provider: provider)
      return client if client.failure?

      conn = client.value
      endpoint = Gemini::Endpoints.text_generate_path(
        provider: provider,
        model: Gemini::Configuration.model,
        project_id: Gemini::Configuration.project_id,
        location: Gemini::Configuration.location
      )

      payload = {
        systemInstruction: { parts: [ { text: system_prompt } ] },
        contents: [ { role: "user", parts: [ { text: { name: name, description: description }.to_json } ] } ],
        generationConfig: { temperature: 0.5, maxOutputTokens: 600, responseMimeType: "application/json" }
      }

      resp = conn.post(endpoint, payload)
      return failure(StandardError.new("Lore request failed"), metadata: { http_status: resp.status, body: resp.body }) unless (200..299).include?(resp.status)

      json = Gemini::ResponseHelpers.normalize_to_hash(resp.body)
      out = extract_json(json)
      return failure(StandardError.new("Invalid lore")) unless out.is_a?(Hash)

      cleaned = {
        short_lore: out["short_lore"].to_s.strip.first(140),
        long_lore: out["long_lore"].to_s.strip.first(1200)
      }
      success(cleaned)
    rescue Faraday::Error => e
      failure(e)
    end

    private

    attr_reader :name, :description

    def system_prompt
      <<~PROMPT.squish
        You write concise, evocative lore blurbs for motif categories to display on websites.
        Produce JSON with keys: short_lore (<=140 chars) and long_lore (<=1000 chars).
        The subject will be an Archetype or a Spirit Animal with a one-line meaning.
        Avoid proper names, politics, profanity, and copyrighted references. No emojis.
      PROMPT
    end

    def extract_json(body)
      # Reuse helpers to pull structured JSON or parse text content
      candidates = Gemini::ResponseHelpers.dig_value(body, :candidates)
      content = Gemini::ResponseHelpers.dig_value(Array(candidates).first || {}, :content)
      parts = Gemini::ResponseHelpers.dig_value(content || {}, :parts)
      Array(parts).each do |part|
        struct = Gemini::ResponseHelpers.dig_value(part, :structValue) || Gemini::ResponseHelpers.dig_value(part, :jsonValue)
        return struct if struct.is_a?(Hash)
        text = Gemini::ResponseHelpers.dig_value(part, :text)
        begin
          parsed = JSON.parse(text.to_s)
          return parsed if parsed.is_a?(Hash)
        rescue StandardError
        end
      end
      nil
    end
  end
end
