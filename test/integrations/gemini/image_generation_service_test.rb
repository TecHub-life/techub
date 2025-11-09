require "test_helper"

module Gemini
  class ImageGenerationServiceTest < ActiveSupport::TestCase
    SAMPLE_IMAGE_BASE64 = Base64.strict_encode64("png-bytes").freeze

    test "returns decoded bytes and writes file when requested" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash-image:generateContent") do |env|
          body = JSON.parse(env.body)
          assert_equal 0.4, body.dig("generationConfig", "temperature")
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
          AppSetting.set_bool(:ai_images, true)
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
        ensure
          AppSetting.set_bool(:ai_images, false)
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
          AppSetting.set_bool(:ai_images, true)
          result = Gemini::ImageGenerationService.call(prompt: "Tech portrait", aspect_ratio: "1:1")
          assert result.failure?
        ensure
          AppSetting.set_bool(:ai_images, false)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "uses vertex endpoint when provider is vertex" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1/projects/test-proj/locations/us-central1/publishers/google/models/gemini-2.5-flash-image:generateContent") do |_env|
          [
            200,
            { "content-type" => "application/json" },
            {
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
          ]
        end
      end

      dummy_conn = Faraday.new(url: "https://us-central1-aiplatform.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "vertex" do
          Gemini::Configuration.stub :project_id, "test-proj" do
            Gemini::Configuration.stub :location, "us-central1" do
              AppSetting.set_bool(:ai_images, true)
              result = Gemini::ImageGenerationService.call(prompt: "Neon TecHub landscape", aspect_ratio: "3:1")

              assert result.success?
              assert_equal "vertex", result.metadata[:provider]
              assert_equal SAMPLE_IMAGE_BASE64, result.value[:data]
            ensure
              AppSetting.set_bool(:ai_images, false)
            end
          end
        end
      end

      stubs.verify_stubbed_calls
    end

    test "prefers explicit provider override" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash-image:generateContent") do |_env|
          [
            200,
            { "content-type" => "application/json" },
            {
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
          ]
        end
      end

      dummy_conn = Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      calls = []
      Gemini::ClientService.stub :call, ->(**kwargs) do
        calls << kwargs[:provider]
        ServiceResult.success(dummy_conn)
      end do
        Gemini::Configuration.stub :provider, "vertex" do
          AppSetting.set_bool(:ai_images, true)
          result = Gemini::ImageGenerationService.call(prompt: "Override prompt", aspect_ratio: "1:1", provider: "ai_studio")

          assert result.success?
          assert_equal [ "ai_studio" ], calls
          assert_equal "ai_studio", result.metadata[:provider]
        ensure
          AppSetting.set_bool(:ai_images, false)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "includes inline image data when reference image is provided" do
      tmp = Tempfile.new(["doctor", ".png"])
      tmp.binmode
      tmp.write("ref-bytes")
      tmp.flush

      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash-image:generateContent") do |env|
          body = JSON.parse(env.body)
          parts = body.dig("contents", 0, "parts")
          inline = parts.detect { |part| part.key?("inlineData") || part.key?("inline_data") }
          refute_nil inline, "expected inline image part"
          payload = inline["inlineData"] || inline["inline_data"]
          assert_equal "image/png", payload["mimeType"] || payload["mime_type"]
          assert_equal Base64.strict_encode64("ref-bytes"), payload["data"]

          [
            200,
            { "content-type" => "application/json" },
            {
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
          ]
        end
      end

      dummy_conn = Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          AppSetting.set_bool(:ai_images, true)
          result = Gemini::ImageGenerationService.call(
            prompt: "Edit this icon",
            aspect_ratio: "1:1",
            reference_image_path: tmp.path
          )

          assert result.success?
        ensure
          AppSetting.set_bool(:ai_images, false)
        end
      end
    ensure
      tmp.close!
      stubs.verify_stubbed_calls
    end

    test "force option bypasses ai_images flag" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash-image:generateContent") do |_env|
          [
            200,
            { "content-type" => "application/json" },
            {
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
          ]
        end
      end

      dummy_conn = Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      AppSetting.set_bool(:ai_images, false)

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          result = Gemini::ImageGenerationService.call(
            prompt: "Forced",
            aspect_ratio: "1:1",
            force: true
          )

          assert result.success?
        end
      end

      stubs.verify_stubbed_calls
    ensure
      AppSetting.set_bool(:ai_images, false)
    end

    test "includes aspect ratio hint when enabled" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash-image:generateContent") do |env|
          body = JSON.parse(env.body)
          assert_equal "16:9", body.dig("generationConfig", "imageConfig", "aspectRatio"), "expected aspectRatio hint to be present"
          [ 200, { "content-type" => "application/json" }, { "candidates" => [ { "content" => { "parts" => [ { "inlineData" => { "mimeType" => "image/png", "data" => SAMPLE_IMAGE_BASE64 } } ] } } ] } ]
        end
      end

      dummy_conn = Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      orig = ENV["GEMINI_INCLUDE_ASPECT_HINT"]
      ENV["GEMINI_INCLUDE_ASPECT_HINT"] = "1"
      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          AppSetting.set_bool(:ai_images, true)
          result = Gemini::ImageGenerationService.call(prompt: "Landscape", aspect_ratio: "16:9")
          assert result.success?
        ensure
          AppSetting.set_bool(:ai_images, false)
        end
      end
      ENV["GEMINI_INCLUDE_ASPECT_HINT"] = orig

      stubs.verify_stubbed_calls
    end
  end
end
