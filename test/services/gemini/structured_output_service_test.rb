require "test_helper"

module Gemini
  class StructuredOutputServiceTest < ActiveSupport::TestCase
    test "ai studio payload uses camelCase and Type Schema" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |env|
          body = JSON.parse(env.body)
          assert_equal "application/json", body.dig("generationConfig", "responseMimeType")
          schema = body.dig("generationConfig", "responseSchema")
          assert_equal "OBJECT", schema["type"]
          assert_equal "STRING", schema.dig("properties", "x", "type")
          [ 200, { "content-type" => "application/json" }, { candidates: [ { content: { parts: [ { text: { x: "ok" }.to_json } ] } } ] } ]
        end
      end

      conn = Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          schema = { type: "object", properties: { x: { type: "string" } } }
          result = Gemini::StructuredOutputService.call(prompt: "p", response_schema: schema)
          assert result.success?
          assert_equal({ "x" => "ok" }, result.value)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "vertex payload uses snake_case keys" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1/projects/proj/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent") do |env|
          body = JSON.parse(env.body)
          assert body.key?("generation_config"), "expected generation_config key"
          schema = body.dig("generation_config", "response_schema")
          assert_equal({ "type" => "object", "properties" => { "y" => { "type" => "string" } } }, schema)
          [ 200, { "content-type" => "application/json" }, { candidates: [ { content: { parts: [ { text: { y: "ok" }.to_json } ] } } ] } ]
        end
      end

      conn = Faraday.new(url: "https://us-central1-aiplatform.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(conn) do
        Gemini::Configuration.stub :provider, "vertex" do
          Gemini::Configuration.stub :project_id, "proj" do
            Gemini::Configuration.stub :location, "us-central1" do
              schema = { type: "object", properties: { y: { type: "string" } } }
              result = Gemini::StructuredOutputService.call(prompt: "p", response_schema: schema)
              assert result.success?
              assert_equal({ "y" => "ok" }, result.value)
            end
          end
        end
      end

      stubs.verify_stubbed_calls
    end
  end
end
