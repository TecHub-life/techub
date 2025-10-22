require "test_helper"

class GeneratePipelineServiceTest < ActiveSupport::TestCase
  test "orchestrates sync, generate, synthesize, and enqueues captures" do
    login = "loftwah"
    profile = Profile.create!(github_id: 42, login: login)

    Profiles::SyncFromGithub.stub :call, ServiceResult.success(profile) do
      ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "0"
      ai_result = ServiceResult.success(ProfileCard.new(id: 1), metadata: { attempts: [] })
      Profiles::SynthesizeAiProfileService.stub :call, ai_result do
        Profiles::SynthesizeCardService.stub :call, ServiceResult.success(ProfileCard.new(id: 1)) do
          result = Profiles::GeneratePipelineService.call(login: login, host: "http://127.0.0.1:3000")

          assert result.success?, -> { result.error&.message }
          assert_equal login, result.value[:login]
          refute result.value.key?(:images), "pipeline output should not include AI image payloads"
          assert_nil result.value[:screenshots], "screenshots are enqueued, not returned"
        ensure
          ENV.delete("REQUIRE_PROFILE_ELIGIBILITY")
        end
      end
    end
  end

  test "eligibility gate denies when flag enabled and not eligible" do
    login = "noneligible"
    profile = Profile.create!(github_id: 43, login: login, followers: 0, following: 0, github_created_at: Time.current)

    Profiles::SyncFromGithub.stub :call, ServiceResult.success(profile) do
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

  test "manual inputs steps run when inputs present and captures are enqueued" do
    login = "flagtest"
    profile = Profile.create!(github_id: 44, login: login, submitted_scrape_url: "https://example.com")

    Profiles::SyncFromGithub.stub :call, ServiceResult.success(profile) do
      begin
        ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "0"
        ai_result = ServiceResult.success(ProfileCard.new(id: 2), metadata: { attempts: [] })
        Profiles::RecordSubmittedScrapeService.stub :call, ServiceResult.success(ProfileScrape.new) do
          Profiles::SynthesizeAiProfileService.stub :call, ai_result do
            Profiles::SynthesizeCardService.stub :call, ServiceResult.success(ProfileCard.new(id: 2)) do
              result = Profiles::GeneratePipelineService.call(login: login)
              assert result.success?
              assert_nil result.value[:screenshots]
            end
          end
        end

        ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "0"
        ai_result = ServiceResult.success(ProfileCard.new(id: 3), metadata: { attempts: [] })
        Profiles::RecordSubmittedScrapeService.stub :call, ServiceResult.success(ProfileScrape.new) do
          Profiles::SynthesizeAiProfileService.stub :call, ai_result do
            Profiles::SynthesizeCardService.stub :call, ServiceResult.success(ProfileCard.new(id: 3)) do
              result = Profiles::GeneratePipelineService.call(login: login)
              assert result.success?
            end
          end
        end
      ensure
        ENV.delete("REQUIRE_PROFILE_ELIGIBILITY")
      end
    end
  end
end
