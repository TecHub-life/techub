require "test_helper"

class Api::V1::ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "assets returns new kinds when present" do
    profile = Profile.create!(github_id: 1, login: "demo")
    %w[card og simple banner x_profile_400 fb_post_1080 ig_portrait_1080x1350].each do |kind|
      ProfileAsset.create!(profile: profile, kind: kind, public_url: "https://cdn/#{kind}.jpg", mime_type: "image/jpeg")
    end

    get "/api/v1/profiles/demo/assets"
    assert_response :success
    json = JSON.parse(@response.body)
    kinds = json.fetch("assets").map { |a| a["kind"] }
    assert_includes kinds, "banner"
    assert_includes kinds, "fb_post_1080"
    assert_includes kinds, "og"
  end
end
