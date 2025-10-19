require "test_helper"

class Api::V1::ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "assets returns new kinds when present" do
    profile = Profile.create!(github_id: 1, login: "demo")
    %w[x_profile_400 x_header_1500x500 ig_square_1080 fb_cover_851x315 linkedin_profile_400 youtube_cover_2560x1440 og_1200x630].each do |kind|
      ProfileAsset.create!(profile: profile, kind: kind, public_url: "https://cdn/#{kind}.jpg", mime_type: "image/jpeg")
    end

    get "/api/v1/profiles/demo/assets"
    assert_response :success
    json = JSON.parse(@response.body)
    kinds = json.fetch("assets").map { |a| a["kind"] }
    assert_includes kinds, "x_profile_400"
    assert_includes kinds, "youtube_cover_2560x1440"
    assert_includes kinds, "og_1200x630"
  end
end
