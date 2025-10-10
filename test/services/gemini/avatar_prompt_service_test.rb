require "test_helper"

module Gemini
  class AvatarPromptServiceTest < ActiveSupport::TestCase
    test "returns combined description and prompt" do
      structured = {
        "facial_features" => "Round glasses, undercut fade.",
        "expression" => "Relaxed grin with bright eyes.",
        "attire" => "Black hoodie with neon trim.",
        "palette" => "Teal gradients with magenta sparks.",
        "background" => "Abstract grid of glowing nodes.",
        "mood" => "Collaborative hacker energy."
      }
      description_result = ServiceResult.success(
        "A playful avatar with teal gradients.",
        metadata: { provider: "ai_studio", structured: structured }
      )

      Gemini::AvatarDescriptionService.stub :call, description_result do
        result = Gemini::AvatarPromptService.call(avatar_path: "public/avatars/demo.png")

        assert result.success?
        assert_equal "A playful avatar with teal gradients.", result.value[:avatar_description]
        assert_equal structured, result.value[:structured_description]

        prompts = result.value[:image_prompts]
        assert_equal %w[1x1 16x9 3x1 9x16], prompts.keys
        prompts.each_value do |prompt|
          assert_match(/Portrait prompt:/, prompt)
          assert_includes prompt, "A playful avatar with teal gradients."
          assert_includes prompt, "Key traits: facial features: Round glasses, undercut fade."
        end

        assert_equal prompts["1x1"], result.value[:image_prompt], "primary prompt should mirror 1x1 variant"
        assert_equal "ai_studio", result.metadata[:provider]
        assert_equal "TecHub", result.metadata[:theme]
        assert_equal "neon-lit anime portrait with confident tech leader energy", result.metadata[:style_profile]
      end
    end

    test "bubbles up description failures" do
      failure = ServiceResult.failure(StandardError.new("nope"))

      Gemini::AvatarDescriptionService.stub :call, failure do
        result = Gemini::AvatarPromptService.call(avatar_path: "public/avatars/demo.png")

        assert result.failure?
        assert_equal "nope", result.error.message
      end
    end
  end
end
