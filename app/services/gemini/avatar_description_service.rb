require "base64"

module Gemini
  class AvatarDescriptionService < ApplicationService
    include Gemini::ResponseHelpers
    TOKEN_STEPS = [ 400, 700, 1000, 1300, 1600 ].freeze
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a meticulous visual analyst for Techub trading cards.
      Only describe elements that are plainly visible. Avoid filler, guesses, or trailing fragments.
    PROMPT

    FALLBACK_PROMPT = <<~PROMPT.squish.freeze
      Describe the person's appearance in this image in 2-3 complete sentences.
      Mention face, expression, clothing, colours, background, and overall vibe.
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

    def initialize(avatar_path:, prompt: DEFAULT_PROMPT, temperature: DEFAULT_TEMPERATURE, max_output_tokens: DEFAULT_MAX_OUTPUT_TOKENS, provider: nil)
      @avatar_path = avatar_path
      @prompt = prompt
      @temperature = temperature
      @max_output_tokens = max_output_tokens
      @provider_override = provider
    end

    def call
      unless FeatureFlags.enabled?(:ai_image_descriptions)
        return failure(
          StandardError.new("image_descriptions_disabled"),
          metadata: { reason: "AI avatar image descriptions are disabled to control costs; prompts will use profile context instead." }
        )
      end

      return failure(StandardError.new("Avatar path is blank")) if avatar_path.blank?

      resolved_path = resolve_path(avatar_path)
      return failure(StandardError.new("Avatar image not found at #{resolved_path}")) unless File.exist?(resolved_path)

      mime_type = detect_mime_type(resolved_path)
      return failure(StandardError.new("Unsupported mime type for avatar image")) unless mime_type&.start_with?("image/")

      image_payload = Base64.strict_encode64(File.binread(resolved_path))
      provider = provider_override.presence || Gemini::Configuration.provider

      client_result = Gemini::ClientService.call(provider: provider)
      return client_result if client_result.failure?

      conn = client_result.value
      attempts = []

      # Progressive retries with higher token limits
      token_limits = TOKEN_STEPS.include?(max_output_tokens) ? TOKEN_STEPS : ([ max_output_tokens ] + TOKEN_STEPS).uniq.sort

      token_limits.each_with_index do |limit, idx|
        response = conn.post(
          Gemini::Endpoints.text_generate_path(
            provider: provider,
            model: Gemini::Configuration.model,
            project_id: Gemini::Configuration.project_id,
            location: Gemini::Configuration.location
          ),
          build_payload(provider, image_payload, mime_type, limit)
        )

        unless (200..299).include?(response.status)
          return failure(
            StandardError.new("Gemini avatar description request failed"),
            metadata: { http_status: response.status, body: response.body }
          )
        end

        description, structured_payload = extract_description(response.body)
        finish_reason = extract_finish_reason(response.body)
        has_text_parts = response_has_text_parts?(response.body)
        attempts << { http_status: response.status, finish_reason: finish_reason, limit: limit }

        if description.present?
          meta = { http_status: response.status, provider: provider, attempts: attempts }
          meta[:structured] = structured_payload if structured_payload.present?
          return success(description.strip, metadata: meta)
        end

        # If provider returned no text parts at all and wasn't truncated, treat as hard failure
        if !has_text_parts && finish_reason != "MAX_TOKENS"
          return failure(
            StandardError.new("Gemini response did not include a description"),
            metadata: { http_status: response.status, body: response.body, attempts: attempts }
          )
        end

        # If truncated, try next, otherwise break to fallback
        break unless finish_reason == "MAX_TOKENS"
        next if idx < token_limits.length - 1
      end

      # Plain-text fallback with small retries
      [ 150, 250, 350 ].each do |limit|
        fallback_result = describe_with_plain_text(conn, provider, image_payload, mime_type, limit)
        if fallback_result.success? && fallback_result.value.to_s.strip.present?
          meta = { http_status: fallback_result.metadata[:http_status], provider: provider, attempts: attempts, fallback_used: true }
          meta[:structured] = fallback_result.metadata[:structured] if fallback_result.metadata[:structured]
          return success(fallback_result.value.strip, metadata: meta)
        end
      end

      failure(
        StandardError.new("Gemini response did not include a description"),
        metadata: { attempts: attempts }
      )
    rescue Faraday::Error => e
      failure(e)
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :avatar_path, :prompt, :temperature, :max_output_tokens, :provider_override

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

    # endpoint computed via Gemini::Endpoints

    def build_payload(provider, image_payload, mime_type, token_limit)
      if provider == "vertex"
        {
          system_instruction: { parts: [ { text: SYSTEM_PROMPT } ] },
          contents: [
            {
              role: "user",
              parts: [
                { text: prompt },
                { inline_data: { mime_type: mime_type, data: image_payload } }
              ]
            }
          ],
          generation_config: {
            temperature: temperature,
            max_output_tokens: token_limit,
            response_mime_type: "application/json",
            response_schema: response_schema
          }
        }
      else
        {
          systemInstruction: { parts: [ { text: SYSTEM_PROMPT } ] },
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
            maxOutputTokens: token_limit,
            responseMimeType: "application/json",
            responseSchema: response_schema
          }
        }
      end
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

    def extract_finish_reason(body)
      data = normalize_to_hash(body)
      return nil if data.blank?
      candidate = Array(dig_value(data, :candidates)).first
      dig_value(candidate, :finishReason)
    end

    def response_has_text_parts?(body)
      data = normalize_to_hash(body)
      return false if data.blank?
      candidate = Array(dig_value(data, :candidates)).first
      content = dig_value(candidate, :content)
      parts = Array(dig_value(content, :parts))
      parts.any? { |part| dig_value(part, :text).present? }
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

      stripped = text.to_s.strip
      if stripped.start_with?("{") && stripped.include?("}")
        json = parse_relaxed_json(text) rescue nil
        return json["description"].to_s.strip if json.is_a?(Hash) && json["description"].present?
      end

      # If the text looks like the start of JSON but isn't complete (e.g. "{"), treat as empty
      return nil if stripped.start_with?("{") && !stripped.include?("}")

      cleaned = stripped
      cleaned = cleaned.gsub(/\s+/, " ")
      cleaned = cleaned.split(/(?<=[.?!])\s*/).map(&:strip).reject(&:blank?).join(" ")
      cleaned.presence
    end

    def parse_relaxed_json(text)
      JSON.parse(text.to_s)
    rescue JSON::ParserError
      cleaned = text.to_s.gsub(/,\s*(?=[}\]])/, "")
      JSON.parse(cleaned)
    end

    def describe_with_plain_text(conn, provider, image_payload, mime_type, token_limit)
      response = conn.post(
        Gemini::Endpoints.text_generate_path(
          provider: provider,
          model: Gemini::Configuration.model,
          project_id: Gemini::Configuration.project_id,
          location: Gemini::Configuration.location
        ),
        fallback_payload(provider, image_payload, mime_type, token_limit)
      )

      unless (200..299).include?(response.status)
        return failure(
          StandardError.new("Gemini fallback description request failed"),
          metadata: { http_status: response.status, body: response.body }
        )
      end

      text = extract_plain_text(response.body)
      text = sanitize_description(text) || text&.strip

      if text.blank?
        return failure(
          StandardError.new("Gemini fallback response did not include a description"),
          metadata: { http_status: response.status, body: response.body }
        )
      end

      success(text, metadata: { http_status: response.status, structured: nil })
    rescue Faraday::Error => e
      failure(e)
    end

    def fallback_payload(provider, image_payload, mime_type, token_limit)
      if provider == "vertex"
        {
          contents: [
            {
              role: "user",
              parts: [
                { text: FALLBACK_PROMPT },
                { inline_data: { mime_type: mime_type, data: image_payload } }
              ]
            }
          ],
          generation_config: {
            temperature: 0.1,
            max_output_tokens: token_limit
          }
        }
      else
        {
          contents: [
            {
              role: "user",
              parts: [
                { text: FALLBACK_PROMPT },
                { inline_data: { mime_type: mime_type, data: image_payload } }
              ]
            }
          ],
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: token_limit
          }
        }
      end
    end

    def extract_plain_text(body)
      data = normalize_to_hash(body)
      return if data.blank?

      candidates = dig_value(data, :candidates)
      return if candidates.blank?

      first_candidate = candidates.first
      content = dig_value(first_candidate, :content)
      return if content.blank?

      parts = dig_value(content, :parts)
      return if parts.blank?

      parts.filter_map { |part| dig_value(part, :text) }.map(&:strip).reject(&:blank?).join(" ")
    end

    # normalize_to_hash, dig_value provided by Gemini::ResponseHelpers
  end
end
