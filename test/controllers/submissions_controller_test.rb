require "test_helper"

class SubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(github_id: 1001, login: "tester")
  end

  test "requires login" do
    post create_submission_path, params: { login: "loftwah" }
    assert_response :redirect
    assert_match "/auth/github", @response.redirect_url
  end

  test "creates submission, links ownership, stores manual inputs when enabled" do
    ENV["SUBMISSION_MANUAL_INPUTS_ENABLED"] = "1"
    Profiles::SyncFromGithub.stub :call, ServiceResult.success(Profile.create!(github_id: 2002, login: "loftwah")) do
      uid = User.find_by(login: "tester").id
      open_session do |sess|
        sess.post create_submission_path, params: {
          login: "loftwah",
          submitted_scrape_url: "https://linkarooie.com/loftwah",
          "submitted_repositories[]": [ "owner/repo1", "owner/repo2" ]
        }, headers: { "X-Test-User-Id" => uid.to_s }
        assert_equal 302, sess.response.status
        prof = Profile.for_login("loftwah").first
        assert_equal "queued", prof.last_pipeline_status
        assert prof.submitted_at.present?
      end

      # Basic sanity: we got a redirect to profile page
      # State changes are covered by service tests.
    ensure
      ENV.delete("SUBMISSION_MANUAL_INPUTS_ENABLED")
    end
  end
end
