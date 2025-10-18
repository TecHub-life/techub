require "test_helper"

class OpsAdminControllerInstallationTest < ActionDispatch::IntegrationTest
  test "shows installation diagnostics and allows fix" do
    ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] = "techub:hunter2"
    Github::FindInstallationService.stub :call, ServiceResult.success({ id: 999, account_login: "owner" }) do
      get ops_admin_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("techub", "hunter2") }
      assert_response :success

      post ops_github_fix_installation_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("techub", "hunter2") }
      assert_response :redirect
      follow_redirect!
      assert_response :success
    end
  ensure
    ENV.delete("MISSION_CONTROL_JOBS_HTTP_BASIC")
  end
end
