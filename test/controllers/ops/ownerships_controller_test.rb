require "test_helper"
require "base64"

class Ops::OwnershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @from_user = User.create!(github_id: 71001, login: "fromuser")
    @to_user = User.create!(github_id: 71002, login: "touser")
    @profile = Profile.create!(github_id: 72001, login: "someone")
    @ownership = ProfileOwnership.create!(user: @from_user, profile: @profile, is_owner: true)

    # In integration tests, bypass HTTP Basic for ops routes to focus on behavior
    Ops::OwnershipsController.skip_before_action :require_ops_basic_auth
  end

  test "transfer moves owner and removes other links" do
    # Add an extra non-owner link to ensure it's cleaned up
    other = User.create!(github_id: 71003, login: "other")
    ProfileOwnership.create!(user: other, profile: @profile, is_owner: false)

    post Rails.application.routes.url_helpers.ops_transfer_ownership_path(@ownership.id),
      params: { target_login: @to_user.login }

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
