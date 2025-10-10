require "test_helper"

module Gemini
  class AvatarImageSuiteServiceTest < ActiveSupport::TestCase
    SAMPLE_PNG_BASE64 = Base64.strict_encode64("bytes").freeze
    SAMPLE_AVATAR_BASE64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==".freeze

    setup do
      @login = "loftwah"
      @avatar_path = Rails.root.join("tmp", "suite-avatar.png")
      FileUtils.mkdir_p(@avatar_path.dirname)
      File.binwrite(@avatar_path, Base64.decode64(SAMPLE_AVATAR_BASE64))
    end

    teardown do
      FileUtils.rm_f(@avatar_path)
      FileUtils.rm_rf(Rails.root.join("tmp", "generated_suite"))
    end

    test "generates all image variants and returns metadata" do
      prompts = {
        "1x1" => "prompt square",
        "16x9" => "prompt wide",
        "3x1" => "prompt banner",
        "9x16" => "prompt vertical"
      }

      structured_description = {
        "description" => "Detailed description.",
        "mood" => "Playful collaborator."
      }

      prompt_result = ServiceResult.success(
        {
          avatar_description: "Detailed description.",
          structured_description: structured_description,
          image_prompt: prompts["1x1"],
          image_prompts: prompts
        },
        metadata: { provider: "vertex" }
      )

      prompt_calls = []
      prompt_service = Class.new do
        class << self
          attr_accessor :response, :calls
          def call(**kwargs)
            calls << kwargs
            response
          end
        end
      end
      prompt_service.response = prompt_result
      prompt_service.calls = prompt_calls

      image_calls = []
      image_service = Class.new do
        class << self
          attr_accessor :responses, :calls
          def call(**kwargs)
            calls << kwargs
            responses.shift
          end
        end
      end
      image_service.calls = image_calls
      image_service.responses = Gemini::AvatarImageSuiteService::VARIANTS.map do |key, variant|
        expected_path = Rails.root.join("tmp", "generated_suite", @login, variant[:filename])
        result_value = {
          data: SAMPLE_PNG_BASE64,
          bytes: "bytes",
          mime_type: "image/png",
          output_path: expected_path.to_s
        }
        ServiceResult.success(result_value, metadata: { aspect_ratio: variant[:aspect_ratio] })
      end

      service = Gemini::AvatarImageSuiteService.new(
        login: @login,
        avatar_path: @avatar_path,
        output_dir: Rails.root.join("tmp", "generated_suite"),
        prompt_service: prompt_service,
        image_service: image_service
      )

      result = service.call

      assert result.success?
      assert_equal "Detailed description.", result.value[:avatar_description]
      assert_equal structured_description, result.value[:structured_description]
      assert_equal prompts, result.value[:prompts]
      assert_equal Rails.root.join("tmp", "generated_suite", @login).to_s, result.value[:output_dir]
      assert_equal 4, result.value[:images].length
      assert_equal [
        {
          avatar_path: @avatar_path,
          prompt_theme: "TecHub",
          style_profile: Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE,
          provider: nil
        }
      ], prompt_service.calls
      expected_image_calls = Gemini::AvatarImageSuiteService::VARIANTS.map do |key, variant|
        {
          prompt: prompts[key],
          aspect_ratio: variant[:aspect_ratio],
          output_path: Rails.root.join("tmp", "generated_suite", @login, variant[:filename]),
          provider: nil
        }
      end
      assert_equal expected_image_calls, image_service.calls
    end

    test "fails when avatar is missing" do
      FileUtils.rm_f(@avatar_path)

      result = Gemini::AvatarImageSuiteService.call(
        login: @login,
        avatar_path: @avatar_path
      )

      assert result.failure?
      assert_match(/not found/i, result.error.message)
    end
  end
end
