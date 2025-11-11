require "test_helper"

class GenerateAiProfileStageTest < ActiveSupport::TestCase
  def setup
    @profile = Profile.create!(
      github_id: 4242,
      login: "fallbacker",
      name: "Fallback Fae",
      followers: 10,
      public_repos: 2
    )
    @profile.profile_languages.create!(name: "Ruby", count: 10)
    @context = Profiles::Pipeline::Context.new(login: @profile.login, host: "http://127.0.0.1:3000")
    @context.profile = @profile
  end

  test "returns success metadata when heuristic fallback runs" do
    ai_failure = ServiceResult.failure(StandardError.new("Invalid structured JSON"), metadata: { provider: "ai_studio" })

    heuristic_stub = lambda do |profile:, persist:|
      card = profile.profile_card || profile.build_profile_card(
        title: "Fallback Hero",
        tagline: "Ships reliable heuristics.",
        attack: 70,
        defense: 65,
        speed: 68,
        tags: %w[coder builder maker hacker engineer devops],
        playing_card: "Ace of ♣",
        spirit_animal: Motifs::Catalog.spirit_animal_names.first,
        archetype: Motifs::Catalog.archetype_names.first
      )
      card.generated_at = Time.current
      card.save!
      ServiceResult.success(card)
    end

    Profiles::SynthesizeAiProfileService.stub :call, ai_failure do
      Profiles::SynthesizeCardService.stub :call, heuristic_stub do
        stage = Profiles::Pipeline::Stages::GenerateAiProfile.new(context: @context)
        result = stage.call

        assert result.success?, -> { result.error&.message }
        assert_not result.degraded?
        assert_equal @profile.profile_card, @context.card
      end
    end
  end
end
