require "test_helper"
require "base64"

class AvatarImageSuiteServiceUploadTest < ActiveSupport::TestCase
  class FakePromptService < ApplicationService
    def initialize(**); end
    def call
      ServiceResult.success(
        {
          avatar_description: "desc",
          structured_description: { "description" => "desc" },
          image_prompts: {
            "1x1" => "p1",
            "16x9" => "p2",
            "3x1" => "p3",
            "9x16" => "p4"
          }
        },
        metadata: { provider: "ai_studio" }
      )
    end
  end

  class FakeImageService < ApplicationService
    def initialize(prompt:, aspect_ratio:, output_path:, **)
      @output_path = output_path
      @aspect_ratio = aspect_ratio
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

  test "adds public_url when upload enabled" do
    login = "upload_user"
    tmp_avatar = Rails.root.join("tmp", "#{login}.png")
    FileUtils.mkdir_p(tmp_avatar.dirname)
    File.binwrite(tmp_avatar, "\x89PNG\r\n")

    ENV["GENERATED_IMAGE_UPLOAD"] = "1"

    Storage::ActiveStorageUploadService.stub :call, ServiceResult.success({ public_url: "https://cdn.example/x.png" }) do
      result = Gemini::AvatarImageSuiteService.call(
        login: login,
        avatar_path: tmp_avatar.to_s,
        output_dir: Rails.root.join("tmp", "generated"),
        prompt_service: FakePromptService,
        image_service: FakeImageService,
        provider: "ai_studio",
        filename_suffix: "ai_studio"
      )

      assert result.success?, -> { result.error&.message }
      images = result.value[:images]
      assert images.values.all? { |p| p[:public_url].present? }, "expected public_url on all variants"
    end
  ensure
    ENV.delete("GENERATED_IMAGE_UPLOAD")
    FileUtils.rm_f(tmp_avatar)
  end
end
