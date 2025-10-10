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
                      { "text" => { story: "Lofty Wah rewired a midnight incident into a celebratory shipping sprint across the Astro seas. Paragraph two celebrates their DevOps beats and collaborative repos. Paragraph three teases a future quantum fleet with friends.", tagline: "Build brilliant, build together" }.to_json }
                    ]
                  },
                  "finishReason" => "STOP"
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
          assert_equal "STOP", result.metadata[:finish_reason]
          assert_match(/Build brilliant, build together/, result.value)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "retries with higher token limit when truncated" do
      call_count = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          call_count += 1
          if call_count == 1
            [
              200,
              { "content-type" => "application/json" },
              {
                "candidates" => [
                  {
                    "content" => {
                      "parts" => [
                        { "text" => { story: "Lofty Wah leads a hackathon cliffhanger", tagline: "Code the tide" }.to_json }
                      ]
                    },
                    "finishReason" => "MAX_TOKENS"
                  }
                ]
              }
            ]
          else
            [
              200,
              { "content-type" => "application/json" },
              {
                "candidates" => [
                  {
                    "content" => {
                      "parts" => [
                        { "text" => { story: "Lofty Wah rebooted a midnight outage into a cooperative maker-festival crescendo over three paragraphs, looping in Ruby rigs and Astro charts. Their collaborators cheer as EddieHub waves crackle with TypeScript arcs. The crew plots the next voyage past SchoolInnovationsAndAchievement, hoisting the linkarooie signal.", tagline: "Keep shipping, keep shining" }.to_json }
                      ]
                    },
                    "finishReason" => "STOP"
                  }
                ]
              }
            ]
          end
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
          assert_includes result.value, "midnight outage"
          assert_equal "STOP", result.metadata[:finish_reason]
          assert_operator result.metadata[:attempts].size, :>=, 2
        end
      end

      stubs.verify_stubbed_calls
    end

    test "recovers when structured output JSON is truncated" do
      call_count = 0
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          call_count += 1
          if call_count == 1
            [
              200,
              { "content-type" => "application/json" },
              {
                "candidates" => [
                  {
                    "content" => {
                      "parts" => [
                        { "text" => "{\n  \"story\": \"From the earliest whispers of open source to the rhythmic beats of music production, Dean" }
                      ]
                    },
                    "finishReason" => "MAX_TOKENS"
                  }
                ]
              }
            ]
          else
            [
              200,
              { "content-type" => "application/json" },
              {
                "candidates" => [
                  {
                    "content" => {
                      "parts" => [
                        { "text" => { story: "Dean charts a vibrant course across open source archipelagos, remixing DevRel tales with technicolor grooves over three friendly paragraphs.", tagline: "Ship brightly, friends" }.to_json }
                      ]
                    },
                    "finishReason" => "STOP"
                  }
                ]
              }
            ]
          end
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
          assert_includes result.value, "Dean charts"
          assert_equal "STOP", result.metadata[:finish_reason]
          assert_equal true, result.metadata[:attempts].first[:partial]
        end
      end

      stubs.verify_stubbed_calls
    end

    test "uses vertex endpoint when provider is vertex" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1/projects/test-proj/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent") do |_env|
          [
            200,
            { "content-type" => "application/json" },
            {
              "candidates" => [
                {
                  "content" => {
                    "parts" => [
                      { "text" => { story: "Dean Lofts orchestrates cloud fleets with hummingbird precision across three celebratory paragraphs.", tagline: "Keep shipping loud" }.to_json }
                    ]
                  },
                  "finishReason" => "STOP"
                }
              ]
            }
          ]
        end
      end

      dummy_conn = Faraday.new(url: "https://us-central1-aiplatform.googleapis.com") do |f|
        f.request :json
        f.response :json
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "vertex" do
          Gemini::Configuration.stub :project_id, "test-proj" do
            Gemini::Configuration.stub :location, "us-central1" do
              result = Profiles::StoryFromProfile.call(login: "loftwah", profile: @profile)

              assert result.success?
              assert_equal "vertex", result.metadata[:provider]
              assert_includes result.value, "Dean Lofts orchestrates cloud fleets"
            end
          end
        end
      end

      stubs.verify_stubbed_calls
    end

    test "prefers explicit provider override" do
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
                      { "text" => { story: "Override provider story for Lofty Wah.", tagline: "Override rules" }.to_json }
                    ]
                  },
                  "finishReason" => "STOP"
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

      calls = []
      Gemini::ClientService.stub :call, ->(**kwargs) do
        calls << kwargs[:provider]
        ServiceResult.success(dummy_conn)
      end do
        Gemini::Configuration.stub :provider, "vertex" do
          result = Profiles::StoryFromProfile.call(login: "loftwah", profile: @profile, provider: "ai_studio")

          assert result.success?
          assert_equal [ "ai_studio" ], calls
          assert_equal "ai_studio", result.metadata[:provider]
          assert_includes result.value, "Override provider story"
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
