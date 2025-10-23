require "test_helper"

module Gemini
  module Providers
    class VertexAdapterTest < ActiveSupport::TestCase
      def setup
        @adapter = Gemini::Providers::VertexAdapter.new
      end

      test "generation config for structured json uses snake_case and standard schema" do
        schema = { type: "object", properties: { title: { type: "string" } }, required: %w[title] }
        cfg = @adapter.generation_config_hash(temperature: 0.5, max_tokens: 256, schema: schema, structured_json: true)

        assert_equal 0.5, cfg.dig(:generation_config, :temperature)
        assert_equal 256, cfg.dig(:generation_config, :max_output_tokens)
        assert_equal "application/json", cfg.dig(:generation_config, :response_mime_type)
        assert_equal schema, cfg.dig(:generation_config, :response_schema)
      end

      test "envelope merges system instruction, contents, and generation config (Vertex)" do
        sys = @adapter.system_instruction_hash("BE STRICT")
        contents = @adapter.contents_for_text("ping")
        cfg = @adapter.generation_config_hash(temperature: 0.2, max_tokens: 16, schema: nil, structured_json: false)
        env = @adapter.envelope(contents: contents, generation_config: cfg, system_instruction: sys)

        assert_equal "BE STRICT", env.dig(:system_instruction, :parts, 0, :text)
        assert_equal "ping", env.dig(:contents, 0, :parts, 0, :text)
        assert_equal 16, env.dig(:generation_config, :max_output_tokens)
      end
    end
  end
end
