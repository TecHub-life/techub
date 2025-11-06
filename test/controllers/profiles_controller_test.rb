require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "cards tab shows empty-state when no assets" do
    profile = Profile.create!(github_id: 2, login: "emptycase")
    get "/profiles/emptycase"
    assert_response :success
    assert_select "p", text: /No card assets yet/  # empty-state message appears
  end
end

require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "shows existing profile" do
    profile = Profile.create!(
      github_id: 12345,
      login: "testuser",
      name: "Test User",
      summary: "A test user",
      followers: 10,
      following: 5,
      public_repos: 20,
      last_synced_at: 30.minutes.ago
    )

    get profile_path(username: "testuser")

    assert_response :success
    assert Profile.exists?(login: "testuser")
  end

  test "handles case insensitive usernames" do
    profile = Profile.create!(
      github_id: 12345,
      login: "testuser",
      name: "Test User",
      summary: "A test user",
      followers: 10,
      following: 5,
      public_repos: 20,
      last_synced_at: 30.minutes.ago
    )

    get profile_path(username: "TESTUSER")

    assert_response :success
  end

  test "redirects to submit for non-existent profile" do
    get profile_path(username: "nonexistentuser123456789")
    assert_redirected_to submit_path
    follow_redirect!
    assert_response :success
    assert_match /profile not found/i, response.body.downcase
  end

  test "profile show renders tags that link to directory" do
    p = Profile.create!(github_id: 10, login: "dana", name: "Dana", last_pipeline_status: "success")
    ProfileCard.create!(profile: p, attack: 10, defense: 10, speed: 10, tags: %w[ruby rails ai js ml data])

    get profile_path(username: "dana")
    assert_response :success
    assert_match /\/directory\?tags=ruby/, @response.body
  end

  test "unlisted profile behaves as missing" do
    profile = Profile.create!(github_id: 55, login: "ghost", listed: false, unlisted_at: Time.current)
    get profile_path(username: profile.login)
    assert_redirected_to submit_path
  end
end
