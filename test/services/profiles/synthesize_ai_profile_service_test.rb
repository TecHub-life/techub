require "test_helper"

module Profiles
  class SynthesizeAiProfileServiceTest < ActiveSupport::TestCase
    def setup
      @profile = Profile.create!(github_id: 9999, login: "tester", name: "Test User")
    end

    test "persists valid AI traits with tags=6 and valid playing_card" do
      payload = {
        title: "The Code Whisperer",
        tagline: "Turns complex repos into calming release cycles.",
        short_bio: "Short bio",
        long_bio: "Long bio" * 20,
        buff: "Quick Learner",
        buff_description: "Great at absorbing new concepts and practices.",
        weakness: "Overcommits",
        weakness_description: "Sometimes takes on too much at once.",
        vibe: "The Creator",
        vibe_description: "Creative energy that turns ideas into systems.",
        special_move: "Refactor Surge",
        special_move_description: "Delivers large refactors safely and quickly.",
        flavor_text: "Ships with care.",
        tags: %w[ruby open-source testing ci-cd devops backend],
        attack: 80,
        defense: 85,
        speed: 78,
        playing_card: "King of ♣",
        spirit_animal: Motifs::Catalog.spirit_animal_names.first,
        archetype: Motifs::Catalog.archetype_names.first
      }

      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          body = { candidates: [ { content: { parts: [ { text: payload.to_json } ] }, finishReason: "STOP" } ] }
          [ 200, { "Content-Type" => "application/json" }, body.to_json ]
        end
      end

      dummy_conn = Faraday.new do |f|
        f.request :json
        f.response :json, content_type: /json/
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          result = Profiles::SynthesizeAiProfileService.call(profile: @profile)
          assert result.success?, "expected success, got: #{result.error&.message}"
          card = @profile.reload.profile_card
          assert_equal payload[:title], card.title
          assert_equal payload[:tagline], card.tagline
          assert_equal 6, Array(card.tags).length
          assert_match(/\A(Ace|[2-9]|10|Jack|Queen|King) of [♣♦♥♠]\z/, card.playing_card)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "strict re-ask fixes invalid output (tags count)" do
      bad = {
        title: "",
        tagline: "Same as flavor",
        short_bio: "short",
        long_bio: "long" * 200,
        buff: "X",
        buff_description: "Y",
        weakness: "Z",
        weakness_description: "W",
        vibe: "The Hero",
        vibe_description: "nice",
        special_move: "Move",
        special_move_description: "desc",
        flavor_text: "tagline",
        tags: %w[ruby open-source ci],
        attack: 50,
        defense: 120,
        speed: 20,
        playing_card: "Joker of ?",
        spirit_animal: Motifs::Catalog.spirit_animal_names.first,
        archetype: Motifs::Catalog.archetype_names.first
      }

      good = bad.merge(
        title: "The Code Whisperer",
        tagline: "Turns complex repos into calming release cycles.",
        tags: %w[ruby open-source testing ci-cd devops backend],
        attack: 70,
        defense: 75,
        speed: 80,
        playing_card: "Ace of ♣"
      )

      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        # First attempt returns invalid JSON content
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          body = { candidates: [ { content: { parts: [ { text: bad.to_json } ] }, finishReason: "STOP" } ] }
          [ 200, { "Content-Type" => "application/json" }, body.to_json ]
        end
        # Second attempt (strict) returns valid content
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          body = { candidates: [ { content: { parts: [ { text: good.to_json } ] }, finishReason: "STOP" } ] }
          [ 200, { "Content-Type" => "application/json" }, body.to_json ]
        end
      end

      dummy_conn = Faraday.new do |f|
        f.request :json
        f.response :json, content_type: /json/
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          res = Profiles::SynthesizeAiProfileService.call(profile: @profile)
          assert res.success?
          card = @profile.reload.profile_card
          assert_equal 6, Array(card.tags).length
          assert_match(/\A(Ace|[2-9]|10|Jack|Queen|King) of [♣♦♥♠]\z/, card.playing_card)
        end
      end

      stubs.verify_stubbed_calls
    end

    test "overrides enforce Loftwah choices" do
      prof = Profile.create!(github_id: 10001, login: "loftwah", name: "Lofty")
      payload = {
        title: "The Trailblazer",
        tagline: "Guides founders through delivery sprints.",
        short_bio: "Short",
        long_bio: "Long" * 200,
        buff: "X",
        buff_description: "Y",
        weakness: "Z",
        weakness_description: "W",
        vibe: "The Hero",
        vibe_description: "nice",
        special_move: "Move",
        special_move_description: "desc",
        flavor_text: "tagline",
        tags: %w[ruby open-source testing ci-cd devops backend],
        attack: 70,
        defense: 75,
        speed: 80,
        playing_card: "7 of ♦",
        spirit_animal: Motifs::Catalog.spirit_animal_names.first,
        archetype: Motifs::Catalog.archetype_names.first
      }

      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          body = { candidates: [ { content: { parts: [ { text: payload.to_json } ] }, finishReason: "STOP" } ] }
          [ 200, { "Content-Type" => "application/json" }, body.to_json ]
        end
      end

      dummy_conn = Faraday.new do |f|
        f.request :json
        f.response :json, content_type: /json/
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          result = Profiles::SynthesizeAiProfileService.call(profile: prof)
          assert result.success?
          card = prof.reload.profile_card
          assert_equal "Ace of ♣", card.playing_card
          assert_equal "Koala", card.spirit_animal
          assert_equal "The Hero", card.archetype
        end
      end

      stubs.verify_stubbed_calls
    end

    test "empty first attempt records preview metadata" do
      good_payload = {
        title: "The Code Whisperer",
        tagline: "Turns complex repos into calming release cycles.",
        short_bio: "Short bio",
        long_bio: "Long bio" * 20,
        buff: "Quick Learner",
        buff_description: "Great at absorbing new concepts and practices.",
        weakness: "Overcommits",
        weakness_description: "Sometimes takes on too much at once.",
        vibe: "The Creator",
        vibe_description: "Creative energy that turns ideas into systems.",
        special_move: "Refactor Surge",
        special_move_description: "Delivers large refactors safely and quickly.",
        flavor_text: "Ships with care.",
        tags: %w[ruby open-source testing ci-cd devops backend],
        attack: 80,
        defense: 85,
        speed: 78,
        playing_card: "King of ♣",
        spirit_animal: Motifs::Catalog.spirit_animal_names.first,
        archetype: Motifs::Catalog.archetype_names.first
      }

      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          empty_body = { candidates: [ { content: { parts: [ { text: "Content filtered by safety." } ] }, finishReason: "SAFETY" } ] }
          [ 200, { "Content-Type" => "application/json" }, empty_body.to_json ]
        end
        stub.post("/v1beta/models/gemini-2.5-flash:generateContent") do |_env|
          body = { candidates: [ { content: { parts: [ { text: good_payload.to_json } ] }, finishReason: "STOP" } ] }
          [ 200, { "Content-Type" => "application/json" }, body.to_json ]
        end
      end

      dummy_conn = Faraday.new do |f|
        f.request :json
        f.response :json, content_type: /json/
        f.adapter :test, stubs
      end

      Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
        Gemini::Configuration.stub :provider, "ai_studio" do
          result = Profiles::SynthesizeAiProfileService.call(profile: @profile)
          assert result.success?
          attempts = result.metadata[:attempts]
          assert_equal true, attempts.first[:empty]
          assert_equal "Content filtered by safety.", attempts.first[:preview]
        end
      end

      stubs.verify_stubbed_calls
    end
  end
end
