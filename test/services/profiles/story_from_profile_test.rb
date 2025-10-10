require "test_helper"
require "ostruct"

module Profiles
  class StoryFromProfileTest < ActiveSupport::TestCase
    def setup
      @profile = OpenStruct.new(
        login: "loftwah",
        name: "Lofty Wah",
        summary: "Platform engineer who loves developer tooling.",
        profile_languages: [
          OpenStruct.new(name: "Ruby", count: 50),
          OpenStruct.new(name: "TypeScript", count: 30)
        ],
        profile_repositories: [
          OpenStruct.new(name: "techhub", repository_type: "top", stargazers_count: 500),
          OpenStruct.new(name: "garden-app", repository_type: "pinned", stargazers_count: 120)
        ],
        profile_organizations: [
          OpenStruct.new(name: "TecHub Collective", login: "Techub"),
          OpenStruct.new(name: nil, login: "OpenGuild")
        ],
        profile_social_accounts: [
          OpenStruct.new(display_name: "@loftwah", provider: "TWITTER"),
          OpenStruct.new(display_name: nil, provider: "BLUESKY")
        ]
      )
    end

    test "returns a micro story for existing profile" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          [
            200,
            { "content-type" => "application/json" },
            {
              "candidates" => [
                {
                  "content" => {
                    "parts" => [
                      { "text" => "Lofty Wah rewired a midnight incident into a celebratory shipping sprint. \"Build brilliant, build together!\"" }
                    ]
                  }
                }
              ]
            }
          ]
        end
      end

      dummy_conn = Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          result = Profiles::StoryFromProfile.call(login: "loftwah", profile: @profile)

          assert result.success?
          assert_includes result.value, "Lofty Wah"
          assert_equal "ai_studio", result.metadata[:provider]
          assert_match(/Build brilliant/, result.value)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "fails when profile missing" do
      Profile.stub :includes, Profile do
        Profile.stub :find_by, nil do
          result = Profiles::StoryFromProfile.call(login: "unknown")
          assert result.failure?
          assert_match(/Profile not found/, result.error.message)
        end
      end
    end
  end
end
