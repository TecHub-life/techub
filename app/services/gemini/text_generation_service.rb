module Gemini
  class TextGenerationService < ApplicationService
    include Gemini::ResponseHelpers

    DEFAULT_TEMPERATURE = 0.3
    DEFAULT_MAX_TOKENS = 800

    def initialize(prompt:, temperature: DEFAULT_TEMPERATURE, max_output_tokens: DEFAULT_MAX_TOKENS, provider: nil)
      @prompt = prompt
      @temperature = temperature
      @max_output_tokens = max_output_tokens
      @provider_override = provider
    end

    def call
      raise ArgumentError, "Prompt cannot be blank" if prompt.to_s.strip.empty?

      provider = provider_override.presence || Gemini::Configuration.provider
      client_result = Gemini::ClientService.call(provider: provider)
      return client_result if client_result.failure?

      conn = client_result.value
      endpoint = Gemini::Endpoints.text_generate_path(
        provider: provider,
        model: Gemini::Configuration.model,
        project_id: Gemini::Configuration.project_id,
        location: Gemini::Configuration.location
      )

      payload = if provider == "vertex"
        {
          contents: [ { role: "user", parts: [ { text: prompt } ] } ],
          generation_config: { temperature: temperature, max_output_tokens: max_output_tokens }
        }
      else
        {
          contents: [ { role: "user", parts: [ { text: prompt } ] } ],
          generationConfig: { temperature: temperature, maxOutputTokens: max_output_tokens }
        }
      end

      resp = conn.post(endpoint, payload)
      unless (200..299).include?(resp.status)
        return failure(StandardError.new("Gemini text generation failed"), metadata: { http_status: resp.status, body: resp.body })
      end

      text = extract_text(resp.body)
      return failure(StandardError.new("Empty text response"), metadata: { body: resp.body }) if text.to_s.strip.empty?

      success(text.strip)
    rescue Faraday::Error => e
      failure(e)
    end

    private

    attr_reader :prompt, :temperature, :max_output_tokens, :provider_override

    def extract_text(body)
      data = normalize_to_hash(body)
      cand = Array(dig_value(data, :candidates)).first
      content = dig_value(cand, :content)
      parts = Array(dig_value(content, :parts))
      parts.filter_map { |p| dig_value(p, :text) }.join(" ")
    end
  end
end
