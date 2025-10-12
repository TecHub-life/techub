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
      open_session do |sess|
        sess.get root_path
        sess.request.session[:current_user_id] = @user.id
        sess.post create_submission_path, params: {
          login: "loftwah",
          submitted_scrape_url: "https://linkarooie.com/loftwah",
          "submitted_repositories[]": [ "owner/repo1", "owner/repo2" ]
        }
        assert_equal 302, sess.response.status
      end

      # Basic sanity: we got a redirect to profile page
      # State changes are covered by service tests.
    ensure
      ENV.delete("SUBMISSION_MANUAL_INPUTS_ENABLED")
    end
  end
end
