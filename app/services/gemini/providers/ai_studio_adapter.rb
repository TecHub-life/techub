module Gemini
  module Providers
    class AiStudioAdapter < Gemini::Providers::Adapter
      def system_instruction_hash(text)
        { systemInstruction: { parts: [ { text: text } ] } }
      end

      def generation_config_hash(temperature:, max_tokens:, schema: nil, structured_json: false)
        cfg = {
          temperature: temperature,
          maxOutputTokens: max_tokens
        }
        if structured_json && schema
          cfg[:responseMimeType] = "application/json"
          type_schema = Gemini::SchemaHelpers.to_ai_studio_type_schema(schema)
          cfg[:responseSchema] = type_schema.respond_to?(:deep_symbolize_keys) ? type_schema.deep_symbolize_keys : type_schema
        end
        { generationConfig: cfg }
      end

      def envelope(contents:, generation_config:, system_instruction: nil)
        env = {}
        env.merge!(system_instruction) if system_instruction
        env[:contents] = contents
        env.merge!(generation_config)
        env
      end
    end
  end
end
