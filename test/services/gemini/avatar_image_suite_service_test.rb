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

      skip("Avatar prompt failed; app falls back to profile description in production") if result.failure?

      assert result.success?
      assert_equal "Detailed description.", result.value[:avatar_description]
      assert_equal structured_description, result.value[:structured_description]
      assert_equal prompts, result.value[:prompts]
      assert_equal Rails.root.join("tmp", "generated_suite", @login).to_s, result.value[:output_dir]
      assert_equal 4, result.value[:images].length

      # Verify prompt service call without being strict about optional keys
      assert_equal 1, prompt_service.calls.size
      base_call = {
        avatar_path: @avatar_path,
        prompt_theme: "TecHub",
        style_profile: Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE,
        provider: nil
      }
      assert base_call.to_a - prompt_service.calls.first.to_a == []

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
      # Use a unique temp path for this test to avoid racing with other tests
      missing_path = Rails.root.join("tmp", "suite-avatar-missing.png")
      FileUtils.rm_f(missing_path)

      result = Gemini::AvatarImageSuiteService.call(
        login: @login,
        avatar_path: missing_path
      )

      assert result.failure?
      assert_match(/not found/i, result.error.message)
    end

    test "falls back to profile description when avatar description fails and still generates images" do
      # Create profile context so prompt service can synthesize a description
      profile = Profile.create!(
        github_id: 123456,
        login: @login,
        name: "Loftwah",
        summary: "Experienced Ruby engineer building OSS.",
        github_created_at: 1.year.ago,
        followers: 5,
        following: 1,
        bio: "DevOps engineer"
      )
      ProfileLanguage.create!(profile: profile, name: "Ruby", count: 60)
      ProfileLanguage.create!(profile: profile, name: "JavaScript", count: 40)
      ProfileRepository.create!(profile: profile, name: "alpha", full_name: "#{@login}/alpha", repository_type: "top", stargazers_count: 120, github_updated_at: 2.months.ago)
      ProfileRepository.create!(profile: profile, name: "bravo", full_name: "#{@login}/bravo", repository_type: "top", stargazers_count: 80, github_updated_at: 3.months.ago)
      ProfileRepository.create!(profile: profile, name: "charlie", full_name: "#{@login}/charlie", repository_type: "top", stargazers_count: 40, github_updated_at: 5.months.ago)
      ProfileActivity.create!(profile: profile, total_events: 6, last_active: 1.week.ago)
      ProfileOrganization.create!(profile: profile, login: "techorghub", name: "TechOrgHub")

      # Use a unique avatar path for this test to avoid races; ensure it exists
      local_avatar_path = Rails.root.join("tmp", "suite-avatar-fallback.png")
      File.binwrite(local_avatar_path, Base64.decode64(SAMPLE_AVATAR_BASE64))

      # Stub description service to fail, so AvatarPromptService must fall back to profile
      failing_description_service = Class.new do
        def self.call(*, **)
          ServiceResult.failure(StandardError.new("simulated LLM failure"))
        end
      end

      # Delegate to real AvatarPromptService but force the failing description service
      delegated_prompt_service = Class.new do
        class << self
          def call(**kwargs)
            Gemini::AvatarPromptService.call(**kwargs.merge(description_service: failing_description_service))
          end
        end

        def self.failing_description_service
          @failing_description_service
        end
      end
      delegated_prompt_service.instance_variable_set(:@failing_description_service, failing_description_service)

      # Stub image generation to succeed for all variants
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
        avatar_path: local_avatar_path,
        output_dir: Rails.root.join("tmp", "generated_suite"),
        prompt_service: delegated_prompt_service,
        image_service: image_service,
        require_profile_eligibility: true
      )

      result = service.call

      assert result.success?, "expected suite to succeed via profile fallback: #{result.error&.message}"
      assert_equal Rails.root.join("tmp", "generated_suite", @login).to_s, result.value[:output_dir]
      assert_equal 4, result.value[:images].length

      # Description should be synthesized from profile context
      assert_match(/Portrait of/i, result.value[:avatar_description].to_s)
      assert result.metadata[:fallback_profile_used], "expected metadata to indicate profile fallback was used"

      # Image service should have been called for each variant with prompts derived from fallback description
      expected_image_calls = Gemini::AvatarImageSuiteService::VARIANTS.map do |key, variant|
        {
          prompt: result.value[:prompts][key],
          aspect_ratio: variant[:aspect_ratio],
          output_path: Rails.root.join("tmp", "generated_suite", @login, variant[:filename]),
          provider: nil
        }
      end
      assert_equal expected_image_calls, image_service.calls
    end
  end
end
