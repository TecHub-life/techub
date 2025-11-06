require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  test "preferred_og_kind defaults to og" do
    profile = Profile.new(login: "tester", github_id: 999)
    profile[:preferred_og_kind] = nil
    assert_equal "og", profile.preferred_og_kind
  end

  test "preferred_og_kind guards invalid values" do
    profile = Profile.new(login: "tester", github_id: 1000, preferred_og_kind: "unknown")
    assert_equal "og", profile.preferred_og_kind
  end

  test "preferred_og_kind returns stored valid value" do
    profile = Profile.new(login: "tester", github_id: 1001, preferred_og_kind: "og_pro")
    assert_equal "og_pro", profile.preferred_og_kind
  end
end

