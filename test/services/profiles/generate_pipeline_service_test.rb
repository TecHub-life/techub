require "test_helper"

class GeneratePipelineServiceTest < ActiveSupport::TestCase
  test "orchestrates sync, generate, synthesize, capture" do
    login = "loftwah"
    prof = Profile.create!(github_id: 42, login: login)

    Profiles::SyncFromGithub.stub :call, ServiceResult.success(prof) do
      ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "0"
      AppSetting.set_bool(:ai_images, true)
      fake_images = { images: { "1x1" => { output_path: "tmp/1.png", mime_type: "image/png" } } }
      dummy_conn = Faraday.new do |f|
        f.request :json
        f.response :json, content_type: /json/
        stubs = Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post("/v1beta/models/gemini-2.5-flash:generateContent") { [ 200, { "Content-Type"=>"application/json" }, { candidates: [] }.to_json ] }
        end
        f.adapter :test, stubs
      end
      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::AvatarImageSuiteService.stub :call, ServiceResult.success(fake_images) do
          # Avoid AI traits network path entirely by forcing heuristic fallback success
          Profiles::SynthesizeAiProfileService.stub :call, ServiceResult.failure(StandardError.new("skip_ai")) do
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
                AppSetting.set_bool(:ai_images, false)
              end
            end
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

  test "manual inputs steps run when inputs present" do
    login = "flagtest"
    prof = Profile.create!(github_id: 44, login: login, submitted_scrape_url: "https://example.com")

    Profiles::SyncFromGithub.stub :call, ServiceResult.success(prof) do
      # Scraper should be invoked when url present (no flag)
      ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "0"
      Profiles::RecordSubmittedScrapeService.stub :call, ServiceResult.success(ProfileScrape.new) do
        dummy_conn = Faraday.new do |f|
          f.request :json
          f.response :json, content_type: /json/
          f.adapter :test, Faraday::Adapter::Test::Stubs.new
        end
        Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
          Gemini::AvatarImageSuiteService.stub :call, ServiceResult.success({ images: {} }) do
            Profiles::SynthesizeAiProfileService.stub :call, ServiceResult.failure(StandardError.new("skip_ai")) do
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
      end
      end

      # Double-check success path still holds
      ENV["REQUIRE_PROFILE_ELIGIBILITY"] = "0"
      Profiles::RecordSubmittedScrapeService.stub :call, ServiceResult.success(ProfileScrape.new) do
        dummy_conn2 = Faraday.new do |f|
          f.request :json
          f.response :json, content_type: /json/
          f.adapter :test, Faraday::Adapter::Test::Stubs.new
        end
        Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn2) do
          Gemini::AvatarImageSuiteService.stub :call, ServiceResult.success({ images: {} }) do
            Profiles::SynthesizeAiProfileService.stub :call, ServiceResult.failure(StandardError.new("skip_ai")) do
              Profiles::SynthesizeCardService.stub :call, ServiceResult.success(ProfileCard.new(id: 3)) do
              Screenshots::CaptureCardService.stub :call, ServiceResult.success({ output_path: "public/generated/#{login}/og.png", mime_type: "image/png", width: 1200, height: 630 }) do
                Images::OptimizeService.stub :call, ServiceResult.success({}) do
                  result = Profiles::GeneratePipelineService.call(login: login)
                  assert result.success?
                ensure
                  ENV.delete("REQUIRE_PROFILE_ELIGIBILITY")
                end
              end
            end
          end
        end
      end
    end
    end
  end
end
