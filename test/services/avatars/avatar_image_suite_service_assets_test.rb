require "test_helper"
require "base64"

class AvatarImageSuiteServiceAssetsTest < ActiveSupport::TestCase
  class FakePromptService < ApplicationService
    def initialize(**); end
    def call
      ServiceResult.success(
        {
          avatar_description: "desc",
          structured_description: { "description" => "desc" },
          image_prompts: { "1x1" => "p1", "16x9" => "p2", "3x1" => "p3", "9x16" => "p4" }
        },
        metadata: { provider: "ai_studio" }
      )
    end
  end

  class FakeImageService < ApplicationService
    def initialize(prompt:, aspect_ratio:, output_path:, **)
      @output_path = output_path
    end
    def call
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

  test "records ProfileAsset rows for variants" do
    login = "asset_user"
    profile = Profile.create!(github_id: 123456, login: login)
    avatar = Rails.root.join("tmp", "#{login}.png")
    FileUtils.mkdir_p(avatar.dirname)
    File.binwrite(avatar, "\x89PNG\r\n")

    result = Avatars::AvatarImageSuiteService.call(
      login: login,
      avatar_path: avatar.to_s,
      output_dir: Rails.root.join("tmp", "generated"),
      prompt_service: FakePromptService,
      image_service: FakeImageService,
      provider: "ai_studio",
      filename_suffix: "ai_studio"
    )

    assert result.success?
    kinds = profile.profile_assets.pluck(:kind)
    assert_includes kinds, "avatar_1x1"
    assert_includes kinds, "avatar_16x9"
    assert_includes kinds, "avatar_3x1"
    assert_includes kinds, "avatar_9x16"
  ensure
    FileUtils.rm_f(avatar)
  end
end
