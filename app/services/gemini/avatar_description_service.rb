require "base64"

module Gemini
  class AvatarDescriptionService < ApplicationService
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a meticulous visual analyst for Techub trading cards.
      Only describe elements that are plainly visible. Avoid filler, guesses, or trailing fragments.
    PROMPT

    DEFAULT_PROMPT = <<~PROMPT.squish.freeze
      Observe the avatar and populate the response schema with grounded details.
      - description: 2-3 complete sentences (each ≥12 words) summarising appearance, attire, setting, and overall vibe.
      - facial_features: key facial details (hair, headwear, facial hair, eyewear).
      - expression: emotional tone or attitude conveyed.
      - attire: clothing, accessories, or props.
      - palette: dominant colours and lighting cues.
      - background: visible backdrop elements or patterns.
      - mood: short descriptor of the overall feel (e.g. "confident hacker energy").
      Conclude sentences with periods.
    PROMPT
    DEFAULT_TEMPERATURE = 0.15
    DEFAULT_MAX_OUTPUT_TOKENS = 400

    def initialize(avatar_path:, prompt: DEFAULT_PROMPT, temperature: DEFAULT_TEMPERATURE, max_output_tokens: DEFAULT_MAX_OUTPUT_TOKENS)
      @avatar_path = avatar_path
      @prompt = prompt
      @temperature = temperature
      @max_output_tokens = max_output_tokens
    end

    def call
      return failure(StandardError.new("Avatar path is blank")) if avatar_path.blank?

      resolved_path = resolve_path(avatar_path)
      return failure(StandardError.new("Avatar image not found at #{resolved_path}")) unless File.exist?(resolved_path)

      mime_type = detect_mime_type(resolved_path)
      return failure(StandardError.new("Unsupported mime type for avatar image")) unless mime_type&.start_with?("image/")

      image_payload = Base64.strict_encode64(File.binread(resolved_path))
      provider = Gemini::Configuration.provider

      client_result = Gemini::ClientService.call
      return client_result if client_result.failure?

      conn = client_result.value
      response = conn.post(endpoint_path(provider), build_payload(provider, image_payload, mime_type))

      unless (200..299).include?(response.status)
        return failure(
          StandardError.new("Gemini avatar description request failed"),
          metadata: { http_status: response.status, body: response.body }
        )
      end

      description, structured_payload = extract_description(response.body)
      if description.blank?
        return failure(StandardError.new("Gemini response did not include a description"), metadata: { body: response.body, structured: structured_payload })
      end

      metadata = {
        http_status: response.status,
        provider: provider
      }
      metadata[:structured] = structured_payload if structured_payload.present?

      success(description.strip, metadata: metadata)
    rescue Faraday::Error => e
      failure(e)
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :avatar_path, :prompt, :temperature, :max_output_tokens

    def resolve_path(input_path)
      path = Pathname.new(input_path.to_s)
      path = Rails.root.join(path) unless path.absolute?
      path
    end

    def detect_mime_type(path)
      Marcel::MimeType.for(path, name: path.basename.to_s)
    rescue StandardError
      nil
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

    def build_payload(provider, image_payload, mime_type)
      {
        systemInstruction: {
          parts: [ { text: SYSTEM_PROMPT } ]
        },
        contents: [
          {
            role: "user",
            parts: [
              { text: prompt },
              { inline_data: { mime_type: mime_type, data: image_payload } }
            ]
          }
        ],
        generationConfig: {
          temperature: temperature,
          maxOutputTokens: max_output_tokens,
          responseMimeType: "application/json",
          responseSchema: response_schema
        }
      }
    end

    def response_schema
      {
        type: "object",
        properties: {
          description: {
            type: "string",
            description: "Two to three complete sentences describing the avatar."
          },
          facial_features: { type: "string" },
          expression: { type: "string" },
          attire: { type: "string" },
          palette: { type: "string" },
          background: { type: "string" },
          mood: { type: "string" }
        },
        required: %w[description facial_features expression attire palette background mood]
      }
    end

    def extract_description(body)
      data = normalize_to_hash(body)
      return [ nil, nil ] if data.blank?

      candidates = dig_value(data, :candidates)
      return [ nil, nil ] if candidates.blank?

      first_candidate = candidates.first
      content = dig_value(first_candidate, :content)
      return [ nil, nil ] if content.blank?

      parts = dig_value(content, :parts)
      return [ nil, nil ] if parts.blank?

      structured_payload = extract_structured_payload(parts)

      text_segments = parts.filter_map { |part| dig_value(part, :text) }.map(&:strip).reject(&:blank?)
      description_text = structured_payload && structured_payload["description"]

      if description_text.blank? && text_segments.present?
        joined = text_segments.join(" ").strip
        parsed_description, parsed_payload = attempt_json_parse(joined)
        structured_payload ||= parsed_payload
        description_text ||= parsed_description
        description_text ||= joined
      end

      [ sanitize_description(description_text), structured_payload ]
    end

    def extract_structured_payload(parts)
      parts.each do |part|
        hash = deep_stringify(part)
        next unless hash

        struct_value = hash["structValue"] || hash["struct_value"]
        return struct_value if valid_structured_payload?(struct_value)

        json_value = hash["jsonValue"] || hash["json_value"]
        return json_value if valid_structured_payload?(json_value)
      end
      nil
    end

    def attempt_json_parse(text)
      return [ nil, nil ] if text.blank?

      json = parse_relaxed_json(text)
      return [ json["description"], json ] if valid_structured_payload?(json)

      [ nil, nil ]
    rescue JSON::ParserError
      [ nil, nil ]
    end

    def deep_stringify(part)
      return unless part.is_a?(Hash)

      part.each_with_object({}) do |(key, value), acc|
        acc[key.to_s] = value.is_a?(Hash) ? deep_stringify(value) : value
      end
    end

    def valid_structured_payload?(payload)
      payload.is_a?(Hash) && payload["description"].present?
    end

    def sanitize_description(text)
      return if text.blank?

      if text.is_a?(Hash) && text["description"].present?
        return text["description"].to_s.strip
      end

      if text.to_s.strip.start_with?("{") && text.to_s.include?("}")
        json = parse_relaxed_json(text) rescue nil
        return json["description"].to_s.strip if json.is_a?(Hash) && json["description"].present?
      end

      cleaned = text.to_s.strip
      # Ensure sentences end with periods and avoid trailing conjunctions.
      cleaned = cleaned.gsub(/\s+/, " ")
      cleaned = cleaned.split(/(?<=[.?!])\s*/).map(&:strip).reject(&:blank?).join(" ")
      cleaned.length >= 30 ? cleaned : nil
    end

    def parse_relaxed_json(text)
      JSON.parse(text.to_s)
    rescue JSON::ParserError
      cleaned = text.to_s.gsub(/,\s*(?=[}\]])/, "")
      JSON.parse(cleaned)
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
