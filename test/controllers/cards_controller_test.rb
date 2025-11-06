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

  test "card_pro view renders professional layout" do
    get "/cards/#{@profile.login}/card_pro"
    assert_response :success
    assert_includes @response.body, "rounded-[32px]"
    assert_includes @response.body, "width: 1280px"
    assert_includes @response.body, @profile.display_name
  end

  test "og_pro view renders professional layout" do
    get "/cards/#{@profile.login}/og_pro"
    assert_response :success
    assert_includes @response.body, "rounded-[32px]"
    assert_includes @response.body, "width: 1200px"
    assert_includes @response.body, @profile.display_name
  end

  test "simple view renders with avatar and name" do
    get card_simple_path(login: @profile.login)
    assert_response :success
    assert_includes @response.body, @profile.display_name
  end

  test "social routes render fixed canvases" do
    checks = [
      [ "/cards/#{@profile.login}/x_profile_400", [ "w-[400px]", "h-[400px]" ] ],
      [ "/cards/#{@profile.login}/x_header_1500x500", [ "w-[1500px]", "h-[500px]" ] ],
      [ "/cards/#{@profile.login}/x_feed_1600x900", [ "w-[1600px]", "h-[900px]" ] ],
      [ "/cards/#{@profile.login}/ig_square_1080", [ "w-[1080px]", "h-[1080px]" ] ],
      [ "/cards/#{@profile.login}/ig_portrait_1080x1350", [ "w-[1080px]", "h-[1350px]" ] ],
      [ "/cards/#{@profile.login}/ig_landscape_1080x566", [ "w-[1080px]", "h-[566px]" ] ],
      [ "/cards/#{@profile.login}/fb_post_1080", [ "w-[1080px]", "h-[1080px]" ] ],
      [ "/cards/#{@profile.login}/fb_cover_851x315", [ "w-[851px]", "h-[315px]" ] ],
      [ "/cards/#{@profile.login}/linkedin_profile_400", [ "w-[400px]", "h-[400px]" ] ],
      [ "/cards/#{@profile.login}/linkedin_cover_1584x396", [ "w-[1584px]", "h-[396px]" ] ],
      [ "/cards/#{@profile.login}/youtube_cover_2560x1440", [ "w-[2560px]", "h-[1440px]" ] ]
    ]

    checks.each do |(path, strings)|
      get path
      assert_response :success
      strings.each { |s| assert_includes @response.body, s }
    end
  end
end
