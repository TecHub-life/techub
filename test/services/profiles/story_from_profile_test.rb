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
      payload = { "story" => long_story("Lofty Wah rewired a midnight incident into a celebratory sprint."), "tagline" => "Build brilliant, build together" }
      metadata = { provider: "ai_studio", finish_reason: "STOP", http_status: 200, raw_text: payload.to_json }

      Gemini::Configuration.stub :provider, "ai_studio" do
        Gemini::StructuredOutputService.stub :call, ->(**kwargs) do
          assert_equal "ai_studio", kwargs[:provider]
          assert kwargs[:max_output_tokens]
          ServiceResult.success(payload, metadata: metadata)
        end do
          result = Profiles::StoryFromProfile.call(login: "loftwah", profile: @profile)

          assert result.success?
          assert_includes result.value, "Lofty Wah"
          assert_equal "ai_studio", result.metadata[:provider]
          assert_equal "STOP", result.metadata[:finish_reason]
          assert_match(/Build brilliant, build together/, result.value)
        end
      end
    end

    test "retries with higher token limit when truncated" do
      calls = []
      responses = [
        ServiceResult.success(
          { "story" => "", "tagline" => "Code the tide" },
          metadata: { provider: "ai_studio", finish_reason: "MAX_TOKENS", http_status: 200, raw_text: "{}" }
        ),
        ServiceResult.success(
          { "story" => long_story("Lofty Wah rebooted a midnight outage into a cooperative maker-festival."), "tagline" => "Keep shipping, keep shining" },
          metadata: { provider: "ai_studio", finish_reason: "STOP", http_status: 200, raw_text: "{}" }
        )
      ]

      Gemini::Configuration.stub :provider, "ai_studio" do
        Gemini::StructuredOutputService.stub :call, ->(**kwargs) do
          calls << kwargs[:max_output_tokens]
          responses.shift || raise("no stubbed response")
        end do
          result = Profiles::StoryFromProfile.call(login: "loftwah", profile: @profile)

          assert result.success?
          assert_includes result.value, "midnight outage"
          assert_equal "STOP", result.metadata[:finish_reason]
          assert_operator result.metadata[:attempts].size, :>=, 2
          assert calls.first < calls.last, "expected progressive token limits"
        end
      end
    end

    test "recovers when structured output JSON is truncated" do
      responses = [
        ServiceResult.success(
          { "story" => nil, "tagline" => nil },
          metadata: { provider: "ai_studio", finish_reason: "MAX_TOKENS", http_status: 200, raw_text: "{\"story\": \"Dean" }
        ),
        ServiceResult.success(
          { "story" => long_story("Dean charts a vibrant course across open source archipelagos, remixing DevRel tales with technicolor grooves over three friendly paragraphs."), "tagline" => "Ship brightly, friends" },
          metadata: { provider: "ai_studio", finish_reason: "STOP", http_status: 200, raw_text: "{}" }
        )
      ]

      Gemini::Configuration.stub :provider, "ai_studio" do
        Gemini::StructuredOutputService.stub :call, ->(**_kwargs) { responses.shift || raise("no stubbed response") } do
          result = Profiles::StoryFromProfile.call(login: "loftwah", profile: @profile)

          assert result.success?
          assert_includes result.value, "Dean charts"
          assert_equal "STOP", result.metadata[:finish_reason]
          assert_equal true, result.metadata[:attempts].first[:partial]
        end
      end
    end

    test "uses vertex provider when configured" do
      providers = []

      Gemini::Configuration.stub :provider, "vertex" do
        Gemini::StructuredOutputService.stub :call, ->(**kwargs) do
          providers << kwargs[:provider]
          ServiceResult.success(
            { "story" => long_story("Dean Lofts orchestrates cloud fleets with hummingbird precision across three celebratory paragraphs."), "tagline" => "Keep shipping loud" },
            metadata: { provider: kwargs[:provider], finish_reason: "STOP", http_status: 200, raw_text: "{}" }
          )
        end do
          result = Profiles::StoryFromProfile.call(login: "loftwah", profile: @profile)

          assert result.success?
          assert_equal [ "vertex" ], providers
          assert_equal "vertex", result.metadata[:provider]
          assert_includes result.value, "Dean Lofts orchestrates cloud fleets"
        end
      end
    end

    test "prefers explicit provider override" do
      providers = []

      Gemini::Configuration.stub :provider, "vertex" do
        Gemini::StructuredOutputService.stub :call, ->(**kwargs) do
          providers << kwargs[:provider]
          ServiceResult.success(
            { "story" => long_story("Override provider story for Lofty Wah."), "tagline" => "Override rules" },
            metadata: { provider: kwargs[:provider], finish_reason: "STOP", http_status: 200, raw_text: "{}" }
          )
        end do
          result = Profiles::StoryFromProfile.call(login: "loftwah", profile: @profile, provider: "ai_studio")

          assert result.success?
          assert_equal [ "ai_studio" ], providers
          assert_equal "ai_studio", result.metadata[:provider]
          assert_includes result.value, "Override provider story"
        end
      end
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

    private

    def long_story(prefix)
      [ prefix, Array.new(140) { |i| "word#{i}" }.join(" ") ].join(" ")
    end
  end
end
