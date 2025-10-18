require "test_helper"

class OpsAdminControllerInstallationTest < ActionDispatch::IntegrationTest
  test "shows installation diagnostics" do
    ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] = "techub:hunter2"
    auth = ActionController::HttpAuthentication::Basic.encode_credentials("techub", "hunter2")
    get ops_admin_path, headers: { "HTTP_AUTHORIZATION" => auth }
    assert_response :success
  ensure
    ENV.delete("MISSION_CONTROL_JOBS_HTTP_BASIC")
  end
end
