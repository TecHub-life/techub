require "test_helper"

class Api::V1::ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "assets returns new kinds when present" do
    profile = Profile.create!(github_id: 1, login: "demo")
    %w[card og simple banner x_profile_400 fb_post_1080 ig_portrait_1080x1350].each do |kind|
      ProfileAsset.create!(profile: profile, kind: kind, public_url: "https://cdn/#{kind}.jpg", mime_type: "image/jpeg")
    end

    get "/api/v1/profiles/demo/assets"
    assert_response :success
    json = JSON.parse(@response.body)
    kinds = json.fetch("assets").map { |a| a["kind"] }
    assert_includes kinds, "banner"
    assert_includes kinds, "fb_post_1080"
    assert_includes kinds, "og"
  end

  test "card endpoint returns stable schema" do
    profile = Profile.create!(
      github_id: 2,
      login: "schemauser",
      name: "Schema User",
      avatar_url: "https://cdn.example/schemauser.png"
    )

    ProfileCard.create!(
      profile: profile,
      title: "Schema Hero",
      tagline: "Schema defender",
      short_bio: "Short bio",
      long_bio: "Long bio that meets validations",
      buff: "Turbo",
      buff_description: "Turbo charge deployments",
      weakness: "Cooldown",
      weakness_description: "Needs a rest after heavy deploys",
      flavor_text: "Ship it!",
      tags: %w[tag-one tag-two tag-three tag-four tag-five tag-six],
      attack: 82,
      defense: 74,
      speed: 79,
      playing_card: "Ace of ♠",
      spirit_animal: "Wombat",
      archetype: "The Explorer",
      vibe: "Builder",
      vibe_description: "Hands-on automation tinkerer",
      special_move: "Deploy Surge",
      special_move_description: "Pushes green builds straight to prod"
    )

    ProfileActivity.create!(
      profile: profile,
      total_events: 12,
      event_breakdown: { "PushEvent" => 8, "PullRequestEvent" => 4 },
      recent_repos: [ "techub/schema" ].to_json,
      last_active: Time.current,
      activity_metrics: {
        "total_contributions" => 120,
        "current_streak" => 3,
        "longest_streak" => 9
      }
    )

    get "/api/v1/profiles/schemauser"
    assert_response :success
    json = JSON.parse(@response.body)

    assert_superset json.fetch("profile"), %w[avatar_url id login name]
    assert_superset json.fetch("card"), %w[
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
    ]
    assert_superset json.fetch("activity"), %w[
      activity_metrics
      current_streak
      event_breakdown
      last_active
      longest_streak
      recent_repos
      score
      total_events
    ]

    get "/api/v1/profiles/schemauser/card"
    assert_response :success
  end

  test "battle_ready endpoint preserves profile and card shape" do
    profile = Profile.create!(
      github_id: 3,
      login: "readyuser",
      name: "Ready User",
      avatar_url: "https://cdn.example/readyuser.png"
    )

    ProfileCard.create!(
      profile: profile,
      title: "Ready Hero",
      tagline: "Always ready",
      short_bio: "Short bio",
      long_bio: "Long bio that meets validations",
      buff: "Momentum",
      buff_description: "Starts fast every battle",
      weakness: "Drift",
      weakness_description: "Can overextend attacks",
      flavor_text: "On the line!",
      tags: %w[tag-one tag-two tag-three tag-four tag-five tag-six],
      attack: 75,
      defense: 77,
      speed: 83,
      playing_card: "King of ♥",
      spirit_animal: "Kookaburra",
      archetype: "The Hero",
      vibe: "Competitor",
      vibe_description: "Thrives under pressure",
      special_move: "First Strike",
      special_move_description: "Opens with a decisive blow"
    )

    get "/api/v1/profiles/battle-ready"
    assert_response :success
    payload = JSON.parse(@response.body)

    assert payload["profiles"].is_a?(Array)
    entry = payload["profiles"].find { |p| p.dig("profile", "login") == "readyuser" }
    refute_nil entry, "readyuser should be included in battle_ready payload"

    assert_superset entry.fetch("profile"), %w[avatar_url id login name]
    assert_superset entry.fetch("card"), %w[
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
    ]
    assert entry.key?("activity"), "battle_ready response should include activity"
  end

  test "assets endpoint hides unlisted profiles" do
    profile = Profile.create!(github_id: 4, login: "hidden", listed: false, unlisted_at: Time.current)
    get "/api/v1/profiles/hidden/assets"
    assert_response :not_found
  end

  test "battle_ready excludes unlisted profiles" do
    profile = Profile.create!(github_id: 5, login: "shadow", listed: false, unlisted_at: Time.current)
    ProfileCard.create!(
      profile: profile,
      title: "Shadow",
      tagline: "Hidden",
      short_bio: "Short",
      long_bio: "Long bio that meets validations",
      buff: "Stealth",
      buff_description: "Hidden",
      weakness: "Sun",
      weakness_description: "Bright",
      flavor_text: "Stay low",
      tags: %w[tag-one tag-two tag-three tag-four tag-five tag-six],
      attack: 10,
      defense: 10,
      speed: 10,
      playing_card: "Ace of ♠",
      spirit_animal: "Wolf",
      archetype: "Rogue",
      vibe: "Chill",
      vibe_description: "Chill",
      special_move: "Hide",
      special_move_description: "Hide quick"
    )
    get "/api/v1/profiles/battle-ready"
    assert_response :success
    payload = JSON.parse(@response.body)
    refute payload.fetch("profiles").any? { |p| p.dig("profile", "login") == "shadow" }
  end

  private

  def assert_superset(actual_hash, required_keys)
    actual_keys = actual_hash.keys.map(&:to_s)
    missing = required_keys.map(&:to_s) - actual_keys
    assert missing.empty?, "Missing expected keys: #{missing.join(', ')}"
  end
end
