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

      Gemini::Configuration.stub :provider, "ai_studio" do
        with_structured_responses([ structured_success(payload) ]) do |_calls|
          result = Profiles::SynthesizeAiProfileService.call(profile: @profile)
          assert result.success?, "expected success, got: #{result.error&.message}"
          card = @profile.reload.profile_card
          assert_equal payload[:title], card.title
          assert_equal payload[:tagline], card.tagline
          assert_equal 6, Array(card.tags).length
          assert_match(/\A(Ace|[2-9]|10|Jack|Queen|King) of [♣♦♥♠]\z/, card.playing_card)
        end
      end
    end

    test "fills missing tags without introducing duplicates" do
      payload = {
        title: "The Tag Wrangler",
        tagline: "Knits calm pipelines out of noisy repos.",
        short_bio: "Short bio",
        long_bio: "Long bio" * 10,
        buff: "Signal Hunter",
        buff_description: "Finds the most important threads in chaotic systems.",
        weakness: "Noisy Coffee",
        weakness_description: "Too many late night caffeine-fueled commits.",
        vibe: "The Creator",
        vibe_description: "Inventive maker energy with steady delivery.",
        special_move: "Refactor Surge",
        special_move_description: "Spins up confident refactors overnight.",
        flavor_text: "Ships quiet excellence.",
        tags: %w[coder dev maker],
        attack: 70,
        defense: 72,
        speed: 75,
        playing_card: "Queen of ♣",
        spirit_animal: Motifs::Catalog.spirit_animal_names.first,
        archetype: Motifs::Catalog.archetype_names.first
      }

      Gemini::Configuration.stub :provider, "ai_studio" do
        with_structured_responses([ structured_success(payload) ]) do
          result = Profiles::SynthesizeAiProfileService.call(profile: @profile)
          assert result.success?, "expected success, got: #{result.error&.message}"
          card = @profile.reload.profile_card
          assert_equal 6, Array(card.tags).length
          assert_equal Array(card.tags).uniq.length, Array(card.tags).length
        end
      end
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

      Gemini::Configuration.stub :provider, "ai_studio" do
        responses = [
          structured_success(bad),
          structured_success(good)
        ]

        with_structured_responses(responses) do
          res = Profiles::SynthesizeAiProfileService.call(profile: @profile)
          assert res.success?
          card = @profile.reload.profile_card
          assert_equal 6, Array(card.tags).length
          assert_match(/\A(Ace|[2-9]|10|Jack|Queen|King) of [♣♦♥♠]\z/, card.playing_card)
        end
      end
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

      Gemini::Configuration.stub :provider, "ai_studio" do
        with_structured_responses([ structured_success(payload) ]) do
          result = Profiles::SynthesizeAiProfileService.call(profile: prof)
          assert result.success?
          card = prof.reload.profile_card
          assert_equal "Ace of ♣", card.playing_card
          assert_equal "Koala", card.spirit_animal
          assert_equal "The Hero", card.archetype
        end
      end
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

      Gemini::Configuration.stub :provider, "ai_studio" do
        responses = [
          ServiceResult.success(
            {},
            metadata: { provider: "ai_studio", finish_reason: "SAFETY", http_status: 200, raw_text: "Content filtered by safety." }
          ),
          structured_success(good_payload)
        ]

        with_structured_responses(responses) do
          result = Profiles::SynthesizeAiProfileService.call(profile: @profile)
          assert result.success?
          attempts = result.metadata[:attempts]
          assert_equal "SAFETY", attempts.first[:finish_reason]
          assert_equal "Content filtered by safety.", attempts.first[:preview]
        end
      end
    end
    private

    def structured_success(payload, finish_reason: "STOP", provider: "ai_studio", raw_text: nil)
      ServiceResult.success(
        payload.transform_keys(&:to_s),
        metadata: {
          provider: provider,
          finish_reason: finish_reason,
          http_status: 200,
          raw_text: raw_text || payload.to_json
        }
      )
    end

    def with_structured_responses(responses)
      calls = []
      Gemini::StructuredOutputService.stub :call, ->(**kwargs) do
        calls << kwargs
        raise "no stubbed response" if responses.empty?
        responses.shift
      end do
        yield calls
      end
    end
  end
end
