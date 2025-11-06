require "test_helper"

class Ops::ProfilesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
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

  teardown do
    clear_enqueued_jobs
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

  test "refresh_assets queues pipeline for missing variants" do
    @profile.profile_assets.create!(kind: "og", local_path: "/tmp/og.png")

    assert_enqueued_jobs 1, only: Profiles::GeneratePipelineJob do
      post Rails.application.routes.url_helpers.ops_refresh_assets_profile_path(username: @profile.login), params: { variants: "og card" }
    end

    job = enqueued_jobs.last
    overrides = job[:args][1]["pipeline_overrides"]
    assert_equal [ "card" ], overrides["screenshot_variants"]
    assert_equal [ "capture_card_screenshots", "optimize_card_images" ], deserialize_symbol_entries(overrides["only_stages"])
  end

  test "refresh_assets skips enqueue when nothing missing" do
    @profile.profile_assets.create!(kind: "og", local_path: "/tmp/og.png")

    assert_no_enqueued_jobs only: Profiles::GeneratePipelineJob do
      post Rails.application.routes.url_helpers.ops_refresh_assets_profile_path(username: @profile.login), params: { variants: "og", only_missing: 1 }
    end

    assert_redirected_to Rails.application.routes.url_helpers.ops_admin_path
    follow_redirect!
    assert_response :success
  end

  test "reroll_github queues pipeline with recipe overrides" do
    assert_enqueued_jobs 1, only: Profiles::GeneratePipelineJob do
      post Rails.application.routes.url_helpers.ops_reroll_github_profile_path(username: @profile.login)
    end

    job = enqueued_jobs.last
    overrides = job[:args][1]["pipeline_overrides"]
    assert_equal Profiles::Pipeline::Recipes::PROFILE_TEXT_FIELDS.map(&:to_s),
      deserialize_symbol_entries(overrides["preserve_profile_fields"])
    assert_equal Profiles::Pipeline::Recipes::GITHUB_CORE.map(&:to_s),
      deserialize_symbol_entries(overrides["only_stages"])
    assert overrides["preserve_profile_avatar"]
  end

  test "refresh_avatar queues avatar-only recipe" do
    assert_enqueued_jobs 1, only: Profiles::GeneratePipelineJob do
      post Rails.application.routes.url_helpers.ops_refresh_avatar_profile_path(username: @profile.login)
    end

    job = enqueued_jobs.last
    overrides = job[:args][1]["pipeline_overrides"]
    refute overrides["preserve_profile_avatar"]
    assert_equal Profiles::Pipeline::Recipes::GITHUB_CORE.map(&:to_s),
      deserialize_symbol_entries(overrides["only_stages"])
  end

  private

  def deserialize_symbol_entries(raw)
    Array(raw).map do |entry|
      if entry.is_a?(Hash) && entry["_aj_serialized"] == "ActiveJob::Serializers::SymbolSerializer"
        entry["value"].to_s
      else
        entry.to_s
      end
    end
  end
end
