require "test_helper"
require "json"
require "base64"

class AvatarImageSuiteServiceTest < ActiveSupport::TestCase
  class FakePromptService < ApplicationService
    def initialize(avatar_path:, prompt_theme: nil, style_profile: nil, provider: nil, profile_context: nil)
      @avatar_path = avatar_path
      @prompt_theme = prompt_theme
      @style_profile = style_profile
      @provider = provider
      @profile_context = profile_context
    end

    def call
      prompts = {
        "1x1" => "Prompt square",
        "16x9" => "Prompt widescreen",
        "3x1" => "Prompt banner",
        "9x16" => "Prompt portrait"
      }

      ServiceResult.success(
        {
          avatar_description: "Synth description",
          structured_description: { "description" => "Synth description", "mood" => "hero" },
          image_prompts: prompts
        },
        metadata: { provider: "ai_studio", theme: "TecHub", style_profile: "neon" }
      )
    end
  end

  class FakeImageService < ApplicationService
    def initialize(prompt:, aspect_ratio:, output_path:, provider: nil, **_)
      @output_path = output_path
      @aspect_ratio = aspect_ratio
      @provider = provider
      @prompt = prompt
    end

    def call
      # Do not write any files; just echo back a plausible payload
      ServiceResult.success(
        {
          data: Base64.strict_encode64("fake"),
          bytes: "fake",
          mime_type: "image/png",
          output_path: @output_path.to_s
        }
      )
    end
  end

  test "writes prompts and metadata artifacts per provider" do
    login = "artifact_user"
    tmp_dir = Rails.root.join("tmp", "artifact_test")
    FileUtils.mkdir_p(tmp_dir)

    # Create a dummy avatar file
    avatar_path = tmp_dir.join("#{login}.png")
    File.binwrite(avatar_path, "\x89PNG\r\n")

    out_dir = tmp_dir.join("generated")

    result = Gemini::AvatarImageSuiteService.call(
      login: login,
      avatar_path: avatar_path.to_s,
      output_dir: out_dir.to_s,
      prompt_service: FakePromptService,
      image_service: FakeImageService,
      provider: "ai_studio",
      filename_suffix: "ai_studio"
    )

    assert result.success?, -> { "expected success, got: #{result.error&.message} metadata=#{result.metadata.inspect}" }

    meta_dir = out_dir.join(login, "meta")
    prompts_path = meta_dir.join("prompts-ai_studio.json")
    meta_path = meta_dir.join("meta-ai_studio.json")

    assert File.exist?(prompts_path), "prompts artifact not written"
    assert File.exist?(meta_path), "meta artifact not written"

    prompts_json = JSON.parse(File.read(prompts_path))
    meta_json = JSON.parse(File.read(meta_path))

    assert_equal "Synth description", prompts_json["avatar_description"]
    assert prompts_json.key?("structured_description"), "missing structured_description"
    assert prompts_json["prompts"].is_a?(Hash), "prompts should be a hash"

    assert_equal "TecHub", meta_json["theme"]
    assert_equal "neon", meta_json["style_profile"]
  ensure
    # best-effort cleanup
    FileUtils.rm_rf(tmp_dir)
  end
end
