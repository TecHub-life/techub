require "test_helper"

class MyProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(github_id: 8001, login: "loftwah")
    @profile = Profile.create!(github_id: 9001, login: "jrh89")
    ProfileOwnership.create!(user: @user, profile: @profile)
  end

  test "requires login" do
    get my_profiles_path
    assert_response :redirect
    assert_match "/auth/github", @response.redirect_url
  end

  test "lists my profiles and can remove" do
    uid = User.find_by(login: "loftwah").id
    open_session do |sess|
      sess.get my_profiles_path, headers: { "X-Test-User-Id" => uid.to_s }
      assert_equal 200, sess.response.status

      assert_difference -> { ProfileOwnership.count }, -1 do
        sess.delete remove_my_profile_path(username: @profile.login), headers: { "X-Test-User-Id" => uid.to_s }
        assert_equal 302, sess.response.status
      end
    end
  end

  test "shows banner when link removed by rightful owner claim" do
    uid = @user.id
    removed_profile = @profile
    NotificationDelivery.create!(
      user_id: uid,
      event: "ownership_link_removed",
      subject_type: "Profile",
      subject_id: removed_profile.id,
      delivered_at: Time.current
    )

    open_session do |sess|
      sess.get my_profiles_path, headers: { "X-Test-User-Id" => uid.to_s }
      assert_equal 200, sess.response.status
      assert_includes sess.response.body, "Your link to @#{removed_profile.login} was removed when @#{removed_profile.login} claimed ownership."
    end
  end
end
