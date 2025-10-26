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

    # Ops auth is bypassed in test environment via Ops::BaseController
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

  test "destroy respects back_to anchor in redirect" do
    profile = Profile.create!(github_id: 91002, login: "deleteme2")
    ProfileStat.create!(
      profile: profile,
      stat_date: Date.today,
      followers: 0,
      following: 0,
      public_repos: 0,
      total_stars: 0,
      total_forks: 0,
      repo_count: 0
    )
    ProfileScrape.create!(profile: profile, url: "https://example.com/2")

    delete Rails.application.routes.url_helpers.ops_destroy_profile_path(username: profile.login, back_to: "#failed-profiles")

    assert_redirected_to Rails.application.routes.url_helpers.ops_admin_path + "#failed-profiles"
    follow_redirect!
    assert_response :success
  end

  test "destroy handles foreign key violation and shows alert" do
    # Simulate an FK violation by stubbing the profile lookup to a fake object
    login = @profile.login
    fake_profile = Object.new
    fake_profile.define_singleton_method(:login) { login }
    fake_profile.define_singleton_method(:destroy!) { raise ActiveRecord::InvalidForeignKey.new("fk violation") }

    Profile.stub :for_login, [ fake_profile ] do
      delete Rails.application.routes.url_helpers.ops_destroy_profile_path(username: login)
    end

    assert_redirected_to Rails.application.routes.url_helpers.ops_admin_path
    follow_redirect!
    assert_response :success
    assert_match /could not delete/i, @response.body
  end
end
