require "test_helper"

module Gemini
  class ImageGenerationServiceTest < ActiveSupport::TestCase
    SAMPLE_IMAGE_BASE64 = Base64.strict_encode64("png-bytes").freeze

    test "returns decoded bytes and writes file when requested" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash-image:generateContent") do |env|
          body = JSON.parse(env.body)
          assert_equal "1:1", body.dig("imageGenerationConfig", "aspectRatio")
          assert_includes body.dig("contents", 0, "parts", 0, "text"), "portrait"

          response_body = {
            "candidates" => [
              {
                "content" => {
                  "parts" => [
                    { "inlineData" => { "mimeType" => "image/png", "data" => SAMPLE_IMAGE_BASE64 } }
                  ]
                }
              }
            ]
          }
          [ 200, { "content-type" => "application/json" }, response_body ]
        end
      end

      dummy_conn = Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          output_path = Rails.root.join("tmp", "generated-avatar.png")
          FileUtils.rm_f(output_path)

          result = Gemini::ImageGenerationService.call(
            prompt: "Tech portrait",
            aspect_ratio: "1:1",
            output_path: output_path
          )

          assert result.success?
          assert_equal SAMPLE_IMAGE_BASE64, result.value[:data]
          assert_equal "image/png", result.value[:mime_type]
          assert_equal output_path.to_s, result.value[:output_path]
          assert File.exist?(output_path), "expected generated file to exist"
          assert_equal "png-bytes", File.binread(output_path)
        end
      end

      stubs.verify_stubbed_calls
    ensure
      File.delete(Rails.root.join("tmp", "generated-avatar.png")) if File.exist?(Rails.root.join("tmp", "generated-avatar.png"))
    end

    test "returns failure when Gemini omits image data" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash-image:generateContent") do |_env|
          [ 200, { "content-type" => "application/json" }, { "candidates" => [ { "content" => { "parts" => [ { "role" => "model" } ] } } ] } ]
        end
      end

      dummy_conn = Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          result = Gemini::ImageGenerationService.call(prompt: "Tech portrait", aspect_ratio: "1:1")
          assert result.failure?
        end
      end

      stubs.verify_stubbed_calls
    end
  end
end
