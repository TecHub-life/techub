require "test_helper"

class Api::V1::Battles::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @profile = Profile.create!(
      github_id: 42,
      login: "battleuser",
      name: "Battle User",
      avatar_url: "https://cdn.example/battleuser.png"
    )

    ProfileCard.create!(
      profile: @profile,
      title: "Battle Hero",
      tagline: "Always fighting",
      short_bio: "Short",
      long_bio: "Long enough biography for validations.",
      buff: "Momentum",
      buff_description: "Punches above their weight.",
      weakness: "Cooldown",
      weakness_description: "Needs a recharge.",
      flavor_text: "In the arena.",
      tags: %w[tag-one tag-two tag-three tag-four tag-five tag-six],
      attack: 88,
      defense: 77,
      speed: 73,
      playing_card: "Queen of ♦",
      spirit_animal: "Taipan",
      archetype: "The Hero",
      vibe: "Aggressor",
      vibe_description: "Hits first, hits hard.",
      special_move: "Alpha Strike",
      special_move_description: "Opens with devastating force."
    )

    ProfileActivity.create!(
      profile: @profile,
      total_events: 20,
      event_breakdown: { "PushEvent" => 12, "PullRequestEvent" => 8 },
      recent_repos: [ "techub/battle" ].to_json,
      last_active: Time.current,
      activity_metrics: {
        "total_contributions" => 200,
        "current_streak" => 5,
        "longest_streak" => 14
      }
    )
  end

  test "card endpoint stays frozen for battles consumers" do
    get "/api/v1/battles/profiles/battleuser/card"
    assert_response :success

    json = JSON.parse(@response.body)
    assert_equal %w[avatar_url id login name], json.fetch("profile").keys.sort
    assert_equal %w[
      archetype
      attack
      buff
      buff_description
      defense
      special_move
      special_move_description
      speed
      spirit_animal
      vibe
      vibe_description
      weakness
      weakness_description
    ], json.fetch("card").keys.sort
    assert_equal %w[
      activity_metrics
      current_streak
      event_breakdown
      last_active
      longest_streak
      recent_repos
      score
      total_events
    ], json.fetch("activity").keys.sort
  end

  test "battle_ready endpoint stays frozen for battles consumers" do
    get "/api/v1/battles/profiles/battle-ready"
    assert_response :success

    payload = JSON.parse(@response.body)
    entry = payload.fetch("profiles").find { |p| p.dig("profile", "login") == "battleuser" }
    refute_nil entry

    assert_equal %w[avatar_url id login name], entry.fetch("profile").keys.sort
    assert_equal %w[
      archetype
      attack
      buff
      buff_description
      defense
      special_move
      special_move_description
      speed
      spirit_animal
      vibe
      vibe_description
      weakness
      weakness_description
    ], entry.fetch("card").keys.sort
    assert entry.key?("activity"), "battle-ready payload should include activity"
  end
end
