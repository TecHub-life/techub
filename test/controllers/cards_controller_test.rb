require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @profile = Profile.create!(
      github_id: 123,
      login: "loftwah",
      name: "Dean Lofts",
      avatar_url: "/avatars/loftwah.png",
      followers: 42
    )
  end

  test "og view renders fixed 1200x630 container" do
    get card_og_path(login: @profile.login)
    assert_response :success
    assert_includes @response.body, "w-[1200px]"
    assert_includes @response.body, "h-[630px]"
    assert_includes @response.body, @profile.display_name
  end

  test "card view renders fixed 1280x720 container" do
    get card_preview_path(login: @profile.login)
    assert_response :success
    assert_includes @response.body, "w-[1280px]"
    assert_includes @response.body, "h-[720px]"
    assert_includes @response.body, @profile.login
  end

  test "simple view renders with avatar and name" do
    get card_simple_path(login: @profile.login)
    assert_response :success
    assert_includes @response.body, @profile.display_name
  end
end
