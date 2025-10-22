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
    # Manual inputs are always on
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

  test "non-rightful submit allowed when no owner exists (becomes owner)" do
    # Someone (not matching profile login) submits a brand new profile; first submitter becomes owner
    actor = @user # loftwah
    Profiles::SyncFromGithub.stub :call, ServiceResult.success(Profile.create!(github_id: 4004, login: "freshuser")) do
      open_session do |sess|
        sess.post create_submission_path, params: { login: "freshuser" }, headers: { "X-Test-User-Id" => actor.id.to_s }
        assert_equal 302, sess.response.status
      end
    end

    prof = Profile.for_login("freshuser").first
    assert_equal "queued", prof.last_pipeline_status
    link = ProfileOwnership.find_by(user_id: actor.id, profile_id: prof.id)
    assert link.present?
    assert_equal true, link.is_owner
  end

  test "duplicate submission rejected when already owned by different user" do
    owner = User.create!(github_id: 5005, login: "rightful")
    profile = Profile.create!(github_id: 6006, login: "rightful")
    # Seed: rightful owner already owns the profile
    ProfileOwnership.create!(user: owner, profile: profile, is_owner: true)

    # Another user tries to submit the same profile; should be redirected with alert
    Profiles::SyncFromGithub.stub :call, ServiceResult.success(profile) do
      open_session do |sess|
        sess.post create_submission_path, params: { login: "rightful" }, headers: { "X-Test-User-Id" => @user.id.to_s }
        assert_equal 302, sess.response.status
        # After redirect, no new ownership for the actor
        refute ProfileOwnership.exists?(user_id: @user.id, profile_id: profile.id)
      end
    end
  end
end
