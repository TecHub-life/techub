require "test_helper"

class MyProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(github_id: 8001, login: "tester")
    @profile = Profile.create!(github_id: 9001, login: "loftwah")
    ProfileOwnership.create!(user: @user, profile: @profile)
  end

  test "requires login" do
    get my_profiles_path
    assert_response :redirect
    assert_match "/auth/github", @response.redirect_url
  end

  test "lists my profiles and can remove" do
    uid = User.find_by(login: "tester").id
    open_session do |sess|
      sess.get my_profiles_path, headers: { "X-Test-User-Id" => uid.to_s }
      assert_equal 200, sess.response.status

      assert_difference -> { ProfileOwnership.count }, -1 do
        sess.delete remove_my_profile_path(username: @profile.login), headers: { "X-Test-User-Id" => uid.to_s }
        assert_equal 302, sess.response.status
      end
    end
  end
end
