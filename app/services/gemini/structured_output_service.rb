module Gemini
  class StructuredOutputService < ApplicationService
    include Gemini::ResponseHelpers

    DEFAULT_TEMPERATURE = 0.2

    def initialize(prompt:, response_schema:, temperature: DEFAULT_TEMPERATURE, max_output_tokens: 800, provider: nil)
      @prompt = prompt
      @response_schema = response_schema
      @temperature = temperature
      @max_output_tokens = max_output_tokens
      @provider_override = provider
    end

    def call
      raise ArgumentError, "Prompt cannot be blank" if prompt.to_s.strip.empty?
      raise ArgumentError, "response_schema must be a Hash" unless response_schema.is_a?(Hash)

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
          generation_config: {
            temperature: temperature,
            max_output_tokens: max_output_tokens,
            response_mime_type: "application/json",
            response_schema: response_schema
          }
        }
      else
        {
          contents: [ { role: "user", parts: [ { text: prompt } ] } ],
          generationConfig: {
            temperature: temperature,
            maxOutputTokens: max_output_tokens,
            responseMimeType: "application/json",
            responseSchema: response_schema
          }
        }
      end

      resp = conn.post(endpoint, payload)
      unless (200..299).include?(resp.status)
        return failure(StandardError.new("Gemini structured output failed"), metadata: { http_status: resp.status, body: resp.body })
      end

      parsed = normalize_to_hash(resp.body)
      candidate = Array(dig_value(parsed, :candidates)).first
      content = dig_value(candidate, :content)
      parts = Array(dig_value(content, :parts))

      json_value = parts.map { |p| dig_value(p, :text) }.compact.join(" ")
      begin
        obj = JSON.parse(json_value)
      rescue JSON::ParserError
        obj = nil
      end

      return failure(StandardError.new("Invalid structured JSON"), metadata: { raw: json_value }) unless obj.is_a?(Hash)

      success(obj)
    rescue Faraday::Error => e
      failure(e)
    end

    private
    attr_reader :prompt, :response_schema, :temperature, :max_output_tokens, :provider_override
  end
end
