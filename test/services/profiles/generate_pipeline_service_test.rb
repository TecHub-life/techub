require "test_helper"

class GeneratePipelineServiceTest < ActiveSupport::TestCase
  test "orchestrates sync, generate, synthesize, capture" do
    login = "loftwah"
    prof = Profile.create!(github_id: 42, login: login)

    Profiles::SyncFromGithub.stub :call, ServiceResult.success(prof) do
      fake_images = { images: { "1x1" => { output_path: "tmp/1.png", mime_type: "image/png" } } }
      Gemini::AvatarImageSuiteService.stub :call, ServiceResult.success(fake_images) do
        Profiles::SynthesizeCardService.stub :call, ServiceResult.success(ProfileCard.new(id: 1)) do
          Screenshots::CaptureCardService.stub :call, ServiceResult.success({ output_path: "public/generated/#{login}/og.png", mime_type: "image/png", width: 1200, height: 630 }) do
            Images::OptimizeService.stub :call, ServiceResult.success({}) do
              result = Profiles::GeneratePipelineService.call(login: login, host: "http://127.0.0.1:3000")
              assert result.success?, -> { result.error&.message }
              assert_equal login, result.value[:login]
              assert result.value[:images]
              assert result.value[:screenshots]
            end
          end
        end
      end
    end
  end
end
