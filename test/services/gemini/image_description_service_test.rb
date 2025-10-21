require "test_helper"
require "securerandom"

module Gemini
  class ImageDescriptionServiceTest < ActiveSupport::TestCase
    SAMPLE_PNG_BASE64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==".freeze

    setup do
      unique = "image-description-test-#{Process.pid}-#{SecureRandom.hex(6)}.png"
      @avatar_path = Rails.root.join("tmp", unique)
      FileUtils.mkdir_p(@avatar_path.dirname)
      File.binwrite(@avatar_path, Base64.decode64(SAMPLE_PNG_BASE64))
    end

    teardown do
      FileUtils.rm_f(@avatar_path)
    end

    test "returns description when Gemini responds with structured text" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |env|
          assert_equal "application/json", env.request_headers["Content-Type"]
          body = JSON.parse(env.body)
          assert_equal Gemini::ImageDescriptionService::SYSTEM_PROMPT, body.dig("systemInstruction", "parts", 0, "text")
          assert_equal "application/json", body.dig("generationConfig", "responseMimeType")
          assert body.dig("generationConfig", "responseSchema").present?, "expected response schema"
          parts = body.fetch("contents").first.fetch("parts")
          assert_equal "Give me a sentence.", parts.first.fetch("text")
          inline = parts.second.fetch("inline_data")
          assert_equal "image/png", inline.fetch("mime_type")
          assert inline.fetch("data").present?, "inline image data should be present"

          response_body = {
            "candidates" => [
              {
                "content" => {
                  "parts" => [
                    {
                      "text" => {
                        description: "A stylized avatar beams confidently under cool studio lights, wearing a charcoal hoodie and bold glasses. Vivid teal and magenta accents ripple across the background, highlighting their upbeat hacker energy.",
                        facial_features: "Clean-shaven, bald head, thick framed glasses.",
                        expression: "Warm smile with relaxed confidence.",
                        attire: "Charcoal hoodie with subtle zipper detail.",
                        palette: "Cool blues, teal highlights, magenta accent lighting.",
                        background: "Soft gradient wash with abstract tech lines.",
                        mood: "Optimistic open-source champion."
                      }.to_json
                    }
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
          AppSetting.set_bool(:ai_image_descriptions, true)
          result = Gemini::ImageDescriptionService.call(
            image_path: @avatar_path.to_s,
            prompt: "Give me a sentence."
          )

          assert result.success?, "expected service to succeed"
          assert_includes result.value, "A stylized avatar beams confidently"
          assert_includes result.value, "Vivid teal and magenta accents"
          assert_equal "ai_studio", result.metadata[:provider]
          assert_equal "Optimistic open-source champion.", result.metadata.dig(:structured, "mood")
          refute result.metadata[:fallback_used], "fallback should not be used"
        ensure
          AppSetting.set_bool(:ai_image_descriptions, false)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "falls back to plain text when structured payload truncated" do
      call_count = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          call_count += 1
          if call_count == 1
            [
              200,
              { "content-type" => "application/json" },
              {
                "candidates" => [
                  {
                    "content" => {
                      "parts" => [
                        { "text" => "{\n  " }
                      ]
                    }
                  }
                ]
              }
            ]
          else
            [
              200,
              { "content-type" => "application/json" },
              {
                "candidates" => [
                  {
                    "content" => {
                      "parts" => [
                        { "text" => "A bald developer with a copper beard smiles in a suit and blue tie. Cool navy lighting and glowing network lines frame the portrait, signalling confident leadership." }
                      ]
                    }
                  }
                ]
              }
            ]
          end
        end
      end

      dummy_conn = Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          AppSetting.set_bool(:ai_image_descriptions, true)
          result = Gemini::ImageDescriptionService.call(image_path: @avatar_path.to_s)

          assert result.success?, "expected fallback to succeed"
          assert_match(/copper beard/, result.value)
          assert result.metadata[:fallback_used], "expected fallback flag in metadata"
          assert_equal "ai_studio", result.metadata[:provider]
        ensure
          AppSetting.set_bool(:ai_image_descriptions, false)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "returns failure when image file is missing" do
      AppSetting.set_bool(:ai_image_descriptions, true)
      result = Gemini::ImageDescriptionService.call(image_path: "tmp/missing-avatar.png")

      assert result.failure?, "expected failure when avatar file missing"
      assert_match(/not found/, result.error.message)
    end

    test "returns failure when Gemini responds without text" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          [
            200,
            { "content-type" => "application/json" },
            { "candidates" => [ { "content" => { "parts" => [ { "role" => "model" } ] } } ] }
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
          AppSetting.set_bool(:ai_image_descriptions, true)
          result = Gemini::ImageDescriptionService.call(image_path: @avatar_path.to_s)

          assert result.failure?, "expected failure when description missing"
        ensure
          AppSetting.set_bool(:ai_image_descriptions, false)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "uses vertex endpoint when provider is vertex" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1/projects/test-proj/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent") do |_env|
          response_body = {
            "candidates" => [
              {
                "content" => {
                  "parts" => [
                    {
                      "text" => {
                        description: "A developer in a denim jacket pilots neon code currents.",
                        facial_features: "Curly hair, glasses.",
                        expression: "Focused grin.",
                        attire: "Denim jacket, band tee.",
                        palette: "Neon blues and violets.",
                        background: "Rendered holographic grid.",
                        mood: "Playful futurist."
                      }.to_json
                    }
                  ]
                }
              }
            ]
          }
          [ 200, { "content-type" => "application/json" }, response_body ]
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
              AppSetting.set_bool(:ai_image_descriptions, true)
              result = Gemini::ImageDescriptionService.call(
                image_path: @avatar_path.to_s,
                prompt: "Summarize the avatar."
              )

              assert result.success?
              assert_equal "vertex", result.metadata[:provider]
              assert_includes result.value, "developer in a denim jacket"
            ensure
              AppSetting.set_bool(:ai_image_descriptions, false)
            end
          end
        end
      end

      stubs.verify_stubbed_calls
    end

    test "prefers explicit provider override" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          [
            200,
            { "content-type" => "application/json" },
            {
              "candidates" => [
                {
                  "content" => {
                    "parts" => [
                      {
                        "text" => {
                          description: "Override description.",
                          facial_features: "override",
                          expression: "override",
                          attire: "override",
                          palette: "override",
                          background: "override",
                          mood: "override"
                        }.to_json
                      }
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
          AppSetting.set_bool(:ai_image_descriptions, true)
          result = Gemini::ImageDescriptionService.call(image_path: @avatar_path.to_s, provider: "ai_studio")

          assert result.success?
          assert_equal [ "ai_studio" ], calls
          assert_equal "ai_studio", result.metadata[:provider]
        ensure
          AppSetting.set_bool(:ai_image_descriptions, false)
        end
      end

      stubs.verify_stubbed_calls
    end
  end
end
