require "test_helper"

class GeneratePipelineServiceTest < ActiveSupport::TestCase
  test "orchestrates sync, generate, synthesize, capture" do
    login = "loftwah"
    prof = Profile.create!(github_id: 42, login: login)

    Profiles::SyncFromGithub.stub :call, ServiceResult.success(prof) do
      ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "0"
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
            ensure
              ENV.delete("REQUIRE_PROFILE_ELIGIBILITY")
            end
          end
        end
      end
    end
  end

  test "eligibility gate denies when flag enabled and not eligible" do
    login = "noneligible"
    prof = Profile.create!(github_id: 43, login: login, followers: 0, following: 0, github_created_at: Time.current)

    Profiles::SyncFromGithub.stub :call, ServiceResult.success(prof) do
      ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "1"
      Eligibility::GithubProfileScoreService.stub :call, ServiceResult.success({ eligible: false, score: 0, threshold: 3, signals: {} }) do
        result = Profiles::GeneratePipelineService.call(login: login)
        assert result.failure?, "expected failure when not eligible"
        assert_equal "profile_not_eligible", result.error.message
      ensure
        ENV.delete("REQUIRE_PROFILE_ELIGIBILITY")
      end
    end
  end

  test "manual inputs steps are gated by flag" do
    login = "flagtest"
    prof = Profile.create!(github_id: 44, login: login, submitted_scrape_url: "https://example.com")

    Profiles::SyncFromGithub.stub :call, ServiceResult.success(prof) do
      # With flag off, these services must not be called
      ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "0"
      Profiles::RecordSubmittedScrapeService.stub :call, ->(*) { raise "should not call when flag off" } do
        Gemini::AvatarImageSuiteService.stub :call, ServiceResult.success({ images: {} }) do
          Profiles::SynthesizeCardService.stub :call, ServiceResult.success(ProfileCard.new(id: 2)) do
            Screenshots::CaptureCardService.stub :call, ServiceResult.success({ output_path: "public/generated/#{login}/og.png", mime_type: "image/png", width: 1200, height: 630 }) do
              Images::OptimizeService.stub :call, ServiceResult.success({}) do
                result = Profiles::GeneratePipelineService.call(login: login)
                assert result.success?
              end
            end
          end
        end
      end

      # With flag on, scraper service should be invoked and return success
      ENV["SUBMISSION_MANUAL_INPUTS_ENABLED"] = "1"
      ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "0"
      Profiles::RecordSubmittedScrapeService.stub :call, ServiceResult.success(ProfileScrape.new) do
        Gemini::AvatarImageSuiteService.stub :call, ServiceResult.success({ images: {} }) do
          Profiles::SynthesizeCardService.stub :call, ServiceResult.success(ProfileCard.new(id: 3)) do
            Screenshots::CaptureCardService.stub :call, ServiceResult.success({ output_path: "public/generated/#{login}/og.png", mime_type: "image/png", width: 1200, height: 630 }) do
              Images::OptimizeService.stub :call, ServiceResult.success({}) do
                result = Profiles::GeneratePipelineService.call(login: login)
                assert result.success?
              ensure
                ENV.delete("SUBMISSION_MANUAL_INPUTS_ENABLED")
                ENV.delete("REQUIRE_PROFILE_ELIGIBILITY")
              end
            end
          end
        end
      end
    end
  end
end
