require "test_helper"

class Profiles::ClaimOwnershipServiceTest < ActiveSupport::TestCase
  def setup
    @owner_user = User.create!(github_id: 11001, login: "jrh89")
    @other_user = User.create!(github_id: 11002, login: "loftwah")
    @profile = Profile.create!(github_id: 21001, login: "jrh89")
  end

  test "first submitter becomes owner when no owner exists" do
    result = Profiles::ClaimOwnershipService.call(user: @other_user, profile: @profile)
    assert result.success?
    o = ProfileOwnership.find_by(user_id: @other_user.id, profile_id: @profile.id)
    assert o.present?
    assert_equal true, o.is_owner
  end

  test "rightful owner later claims and others removed" do
    Profiles::ClaimOwnershipService.call(user: @other_user, profile: @profile)
    assert ProfileOwnership.exists?(user_id: @other_user.id, profile_id: @profile.id)

    result = Profiles::ClaimOwnershipService.call(user: @owner_user, profile: @profile)
    assert result.success?
    new_owner = ProfileOwnership.find_by(user_id: @owner_user.id, profile_id: @profile.id)
    refute_nil new_owner
    assert_equal true, new_owner.is_owner

    refute ProfileOwnership.exists?(user_id: @other_user.id, profile_id: @profile.id)
  end

  test "single owner invariant: cannot set two owners" do
    Profiles::ClaimOwnershipService.call(user: @owner_user, profile: @profile)
    owner_link = ProfileOwnership.find_by(user_id: @owner_user.id, profile_id: @profile.id)
    assert_equal true, owner_link.is_owner

    bad = ProfileOwnership.new(user: @other_user, profile: @profile, is_owner: true)
    assert_equal false, bad.valid?
    assert_includes bad.errors.full_messages.join(" "), "Profile already has an owner"
  end
end
