require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "shows existing profile" do
    profile = Profile.create!(
      github_login: "testuser",
      name: "Test User",
      summary: "A test user",
      data: {
        profile: {
          login: "testuser",
          name: "Test User",
          followers: 10,
          following: 5,
          public_repos: 20
        },
        top_repositories: [],
        pinned_repositories: [],
        active_repositories: [],
        languages: {}
      },
      last_synced_at: 30.minutes.ago
    )

    get profile_path(username: "testuser")

    assert_response :success
    assert Profile.exists?(github_login: "testuser")
  end

  test "handles case insensitive usernames" do
    profile = Profile.create!(
      github_login: "testuser",
      name: "Test User",
      summary: "A test user",
      data: {
        profile: {
          login: "testuser",
          name: "Test User",
          followers: 10,
          following: 5,
          public_repos: 20
        },
        top_repositories: [],
        pinned_repositories: [],
        active_repositories: [],
        languages: {}
      },
      last_synced_at: 30.minutes.ago
    )

    get profile_path(username: "TESTUSER")

    assert_response :success
  end

  test "shows error for non-existent GitHub user" do
    Profiles::SyncFromGithub.stub :call, ServiceResult.failure(Octokit::NotFound.new) do
      get profile_path(username: "nonexistentuser123456789")

      assert_response :success
      assert_match /not found/i, response.body.downcase
    end
  end
end
