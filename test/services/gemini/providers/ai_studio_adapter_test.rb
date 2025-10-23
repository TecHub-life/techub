require "test_helper"

module Gemini
  module Providers
    class AIStudioAdapterTest < ActiveSupport::TestCase
      def setup
        @adapter = Gemini::Providers::AiStudioAdapter.new
      end

      test "generation config for structured json uses camelCase and Type Schema" do
        schema = { type: "object", properties: { name: { type: "string" }, age: { type: "integer" } }, required: %w[name age] }
        cfg = @adapter.generation_config_hash(temperature: 0.3, max_tokens: 123, schema: schema, structured_json: true)

        assert_equal 0.3, cfg.dig(:generationConfig, :temperature)
        assert_equal 123, cfg.dig(:generationConfig, :maxOutputTokens)
        assert_equal "application/json", cfg.dig(:generationConfig, :responseMimeType)
        type_schema = cfg.dig(:generationConfig, :responseSchema)
        assert_equal "OBJECT", type_schema[:type]
        assert_equal "STRING", type_schema.dig(:properties, :name, :type)
        assert_equal "INTEGER", type_schema.dig(:properties, :age, :type)
      end

      test "envelope merges system instruction, contents, and generation config (AI Studio)" do
        sys = @adapter.system_instruction_hash("RULES")
        contents = @adapter.contents_for_text("hello")
        cfg = @adapter.generation_config_hash(temperature: 0.1, max_tokens: 10, schema: nil, structured_json: false)
        env = @adapter.envelope(contents: contents, generation_config: cfg, system_instruction: sys)

        assert_equal "RULES", env.dig(:systemInstruction, :parts, 0, :text)
        assert_equal "hello", env.dig(:contents, 0, :parts, 0, :text)
        assert_equal 10, env.dig(:generationConfig, :maxOutputTokens)
      end
    end
  end
end
