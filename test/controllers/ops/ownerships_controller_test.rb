require "test_helper"

class Ops::OwnershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @from_user = User.create!(github_id: 71001, login: "fromuser")
    @to_user = User.create!(github_id: 71002, login: "touser")
    @profile = Profile.create!(github_id: 72001, login: "someone")
    @ownership = ProfileOwnership.create!(user: @from_user, profile: @profile, is_owner: true)

    # Stub basic auth for ops routes
    @basic = "admin:secret"
    ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] = @basic
  end

  teardown do
    ENV.delete("MISSION_CONTROL_JOBS_HTTP_BASIC")
  end

  test "transfer moves owner and removes other links" do
    # Add an extra non-owner link to ensure it's cleaned up
    other = User.create!(github_id: 71003, login: "other")
    ProfileOwnership.create!(user: other, profile: @profile, is_owner: false)

    post Rails.application.routes.url_helpers.transfer_ownership_path(@ownership.id),
      params: { target_login: @to_user.login },
      headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(@basic.split(":", 2).first, @basic.split(":", 2).last) }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    # New owner set
    new_owner_link = ProfileOwnership.find_by(user_id: @to_user.id, profile_id: @profile.id)
    assert new_owner_link.present?
    assert_equal true, new_owner_link.is_owner

    # Old links removed
    refute ProfileOwnership.exists?(id: @ownership.id)
    refute ProfileOwnership.exists?(user_id: User.find_by(login: "other").id, profile_id: @profile.id)
  end
end
