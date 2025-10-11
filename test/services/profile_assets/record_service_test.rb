require "test_helper"

class ProfileAssetRecordServiceTest < ActiveSupport::TestCase
  test "creates or updates profile asset" do
    profile = Profile.create!(github_id: 777, login: "tester")
    result = ProfileAssets::RecordService.call(
      profile: profile,
      kind: "og",
      local_path: "public/generated/tester/og.png",
      public_url: "https://cdn.example/og.png",
      mime_type: "image/png",
      width: 1200,
      height: 630,
      provider: "screenshot"
    )
    assert result.success?, -> { result.error&.message }
    rec = result.value
    assert_equal profile, rec.profile
    assert_equal "og", rec.kind
    assert_equal 1200, rec.width
    # update
    result2 = ProfileAssets::RecordService.call(
      profile: profile,
      kind: "og",
      local_path: "public/generated/tester/og2.png",
      public_url: "https://cdn.example/og2.png",
      mime_type: "image/png",
      width: 1200,
      height: 630,
      provider: "screenshot"
    )
    assert result2.success?
    assert_equal "https://cdn.example/og2.png", result2.value.public_url
  end
end
