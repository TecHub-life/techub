module Gemini
  class StructuredOutputService < ApplicationService
    include Gemini::ResponseHelpers
    include Gemini::SchemaHelpers

    DEFAULT_TEMPERATURE = 0.2

    def initialize(prompt:, response_schema:, temperature: DEFAULT_TEMPERATURE, max_output_tokens: 800, provider: nil, system_instruction: nil)
      @prompt = prompt
      @response_schema = response_schema
      @temperature = temperature
      @max_output_tokens = max_output_tokens
      @provider_override = provider
      @system_instruction = system_instruction
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

      adapter = Gemini::Providers::Adapter.for(provider)
      contents = adapter.contents_for_text(prompt)
      generation_config = adapter.generation_config_hash(
        temperature: temperature,
        max_tokens: max_output_tokens,
        schema: response_schema,
        structured_json: true
      )
      instruction = system_instruction.present? ? adapter.system_instruction_hash(system_instruction) : nil
      payload = adapter.envelope(contents: contents, generation_config: generation_config, system_instruction: instruction)

      resp = conn.post(endpoint, payload)
      unless (200..299).include?(resp.status)
        return failure(
          StandardError.new("Gemini structured output failed"),
          metadata: { http_status: resp.status, provider: provider, endpoint: endpoint, body_preview: resp.body.to_s[0, 500] }
        )
      end

      parsed = normalize_to_hash(resp.body)
      candidate = Array(dig_value(parsed, :candidates)).first
      content = dig_value(candidate, :content)
      parts = Array(dig_value(content, :parts))
      finish_reason = dig_value(candidate, :finishReason) || dig_value(candidate, :finish_reason)

      obj = extract_structured_json(parts)
      if obj.blank?
        json_text = parts.filter_map { |p| dig_value(p, :text) }.join(" ")
        obj = parse_relaxed_json(json_text)
        return failure(
          StandardError.new("Invalid structured JSON"),
          metadata: { provider: provider, raw_preview: json_text.to_s[0, 500], http_status: resp.status }
        ) unless obj.is_a?(Hash)
      end

      raw_text = parts.filter_map { |p| dig_value(p, :text) }.join(" ")

      success(
        obj,
        metadata: {
          provider: provider,
          finish_reason: finish_reason,
          http_status: resp.status,
          raw_text: raw_text.presence
        }.compact
      )
    rescue Faraday::Error => e
      failure(e)
    end

    private
    attr_reader :prompt, :response_schema, :temperature, :max_output_tokens, :provider_override, :system_instruction

    def extract_structured_json(parts)
      Array(parts).each do |part|
        part_hash = part.is_a?(Hash) ? part : part.to_h rescue {}
        # functionCall / function_call → args / arguments
        fc = dig_value(part_hash, :functionCall) || dig_value(part_hash, :function_call)
        if fc
          args = dig_value(fc, :args) || dig_value(fc, :arguments)
          return args if args.is_a?(Hash)
          begin
            parsed = JSON.parse(args.to_s)
            return parsed if parsed.is_a?(Hash)
          rescue JSON::ParserError
          end
        end

        struct = dig_value(part_hash, :structValue) || dig_value(part_hash, :struct_value)
        return struct if struct.is_a?(Hash)

        jsonv = dig_value(part_hash, :jsonValue) || dig_value(part_hash, :json_value)
        return jsonv if jsonv.is_a?(Hash)
      end
      nil
    end

    def to_ai_studio_type_schema(schema)
      # Transform JSON Schema-like hashes to AI Studio Type Schema with UPPERCASE types
      return {} unless schema.is_a?(Hash)

      transform = lambda do |node|
        return node unless node.is_a?(Hash)

        out = {}
        node.each do |k, v|
          key = k.to_s
          case key
          when "type"
            out[key] = map_type_to_ai_studio(v)
          when "properties"
            props = {}
            v.to_h.each { |pk, pv| props[pk.to_s] = transform.call(pv) }
            out[key] = props
          when "items"
            out[key] = transform.call(v)
          else
            out[key] = v.is_a?(Hash) ? transform.call(v) : v
          end
        end
        out
      end

      transform.call(schema)
    end

    def map_type_to_ai_studio(value)
      t = value.to_s.downcase
      case t
      when "object" then "OBJECT"
      when "string" then "STRING"
      when "integer" then "INTEGER"
      when "number" then "NUMBER"
      when "array" then "ARRAY"
      when "boolean" then "BOOLEAN"
      else value
      end
    end
  end
end
