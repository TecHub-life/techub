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

  test "missing_asset_variants returns kinds absent from profile assets" do
    profile = Profile.create!(login: "assets", github_id: 2001)
    profile.profile_assets.create!(kind: "og", local_path: "/tmp/og.png")

    missing = profile.missing_asset_variants([ "og", "card", "simple" ])

    assert_equal [ "card", "simple" ], missing
  end

  test "missing_asset_variants defaults to pipeline variants" do
    profile = Profile.create!(login: "empty-assets", github_id: 2002)

    missing = profile.missing_asset_variants

    assert_equal Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS.sort, missing.sort
  end
end
