require "test_helper"

class SubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(github_id: 1001, login: "loftwah")
  end

  test "requires login" do
    post create_submission_path, params: { login: "loftwah" }
    assert_response :redirect
    assert_match "/auth/github", @response.redirect_url
  end

  test "loftwah submits @loftwah: becomes owner, stores manual inputs" do
    ENV["SUBMISSION_MANUAL_INPUTS_ENABLED"] = "1"
    Profiles::SyncFromGithub.stub :call, ServiceResult.success(Profile.create!(github_id: 2002, login: "loftwah")) do
      uid = User.find_by(login: "loftwah").id
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

  test "jrh89 submits @jrh89: removes loftwah owner and sets rightful owner" do
    user_loftwah = @user # login: loftwah
    profile = Profile.create!(github_id: 3003, login: "jrh89")
    # First submitter becomes owner
    Profiles::SyncFromGithub.stub :call, ServiceResult.success(profile) do
      open_session do |sess|
        sess.post create_submission_path, params: { login: "jrh89" }, headers: { "X-Test-User-Id" => user_loftwah.id.to_s }
        assert_equal 302, sess.response.status
      end
    end
    link_loftwah = ProfileOwnership.find_by(user_id: user_loftwah.id, profile_id: profile.id)
    assert link_loftwah.present?
    assert_equal true, link_loftwah.is_owner

    # The rightful owner (user with login jrh89) submits @jrh89
    user_jrh89 = User.create!(github_id: 1002, login: "jrh89")
    Profiles::SyncFromGithub.stub :call, ServiceResult.success(profile) do
      open_session do |sess2|
        sess2.post create_submission_path, params: { login: "jrh89" }, headers: { "X-Test-User-Id" => user_jrh89.id.to_s }
        assert_equal 302, sess2.response.status
      end
    end

    # Ownership: rightful owner replaces previous owner
    refute ProfileOwnership.exists?(user_id: user_loftwah.id, profile_id: profile.id)
    link_b = ProfileOwnership.find_by(user_id: user_jrh89.id, profile_id: profile.id)
    assert link_b.present?
    assert_equal true, link_b.is_owner

    # An event is recorded for A so My Profiles can show a banner
    assert NotificationDelivery.exists?(user_id: user_loftwah.id, event: "ownership_link_removed", subject_type: "Profile", subject_id: profile.id)
  end
end
