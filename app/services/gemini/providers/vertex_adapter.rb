require_dependency "gemini/providers/adapter"

module Gemini
  module Providers
    class VertexAdapter < Gemini::Providers::Adapter
      def system_instruction_hash(text)
        { system_instruction: { parts: [ { text: text } ] } }
      end

      def generation_config_hash(temperature:, max_tokens:, schema: nil, structured_json: false)
        cfg = {
          temperature: temperature,
          max_output_tokens: max_tokens
        }
        if structured_json && schema
          cfg[:response_mime_type] = "application/json"
          cfg[:response_schema] = schema
        end
        { generation_config: cfg }
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
