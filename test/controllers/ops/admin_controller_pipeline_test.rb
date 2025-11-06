require "test_helper"

class OpsAdminControllerPipelineTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    @profile = Profile.create!(github_id: 92001, login: "asset-job")
    @profile.profile_assets.create!(kind: "og", local_path: "/tmp/og.png")
  end

  teardown do
    clear_enqueued_jobs
  end

  test "bulk_refresh_assets enqueues jobs for matching profiles" do
    assert_enqueued_jobs 1, only: Profiles::GeneratePipelineJob do
      post Rails.application.routes.url_helpers.ops_bulk_refresh_assets_path, params: {
        logins: @profile.login,
        variants: "og card",
        only_missing: "1"
      }
    end
    assert_redirected_to Rails.application.routes.url_helpers.ops_admin_path(anchor: "pipeline")

    job = enqueued_jobs.last
    overrides = job[:args][1]["pipeline_overrides"]
    assert_equal [ "card" ], overrides["screenshot_variants"]
  end

  test "bulk_refresh_assets no-ops when nothing missing" do
    assert_no_enqueued_jobs only: Profiles::GeneratePipelineJob do
      post Rails.application.routes.url_helpers.ops_bulk_refresh_assets_path, params: {
        logins: @profile.login,
        variants: "og",
        only_missing: "1"
      }
    end

    assert_redirected_to Rails.application.routes.url_helpers.ops_admin_path(anchor: "pipeline")
  end

  test "bulk_refresh_github enqueues recipe jobs" do
    assert_enqueued_jobs 1, only: Profiles::GeneratePipelineJob do
      post Rails.application.routes.url_helpers.ops_bulk_refresh_github_path, params: {
        logins: @profile.login,
        mode: "github"
      }
    end
    assert_redirected_to Rails.application.routes.url_helpers.ops_admin_path(anchor: "pipeline")

    overrides = enqueued_jobs.last[:args][1]["pipeline_overrides"]
    assert overrides["preserve_profile_avatar"]
    assert_equal Profiles::Pipeline::Recipes::GITHUB_CORE.map(&:to_s),
      deserialize_symbol_entries(overrides["only_stages"])
  end

  test "bulk_refresh_github avatar mode disables avatar preservation" do
    assert_enqueued_jobs 1, only: Profiles::GeneratePipelineJob do
      post Rails.application.routes.url_helpers.ops_bulk_refresh_github_path, params: {
        logins: @profile.login,
        mode: "avatar"
      }
    end
    assert_redirected_to Rails.application.routes.url_helpers.ops_admin_path(anchor: "pipeline")

    overrides = enqueued_jobs.last[:args][1]["pipeline_overrides"]
    refute overrides["preserve_profile_avatar"]
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
