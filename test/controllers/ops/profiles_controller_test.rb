require "test_helper"

class Ops::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @profile = Profile.create!(github_id: 91001, login: "deleteme")
    ProfileStat.create!(
      profile: @profile,
      stat_date: Date.today,
      followers: 1,
      following: 0,
      public_repos: 0,
      total_stars: 0,
      total_forks: 0,
      repo_count: 0
    )
    ProfileScrape.create!(profile: @profile, url: "https://example.com")

    Ops::ProfilesController.skip_before_action :require_ops_basic_auth
  end

  test "destroy removes profile and related records" do
    assert_difference -> { Profile.count }, -1 do
      assert_difference -> { ProfileStat.count }, -1 do
        assert_difference -> { ProfileScrape.count }, -1 do
          delete Rails.application.routes.url_helpers.ops_destroy_profile_path(username: @profile.login)
        end
      end
    end

    assert_redirected_to Rails.application.routes.url_helpers.ops_admin_path
    follow_redirect!
    assert_response :success
    refute Profile.exists?(id: @profile.id)
  end
end
