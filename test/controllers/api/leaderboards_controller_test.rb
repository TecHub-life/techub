require "test_helper"

class ApiLeaderboardsControllerTest < ActionDispatch::IntegrationTest
  test "podium returns top 3" do
    Profile.create!(github_id: 1, login: "aa", followers: 3)
    Profile.create!(github_id: 2, login: "bb", followers: 2)
    Profile.create!(github_id: 3, login: "cc", followers: 1)

    Leaderboards::ComputeService.call(kind: "followers_total", window: "all", as_of: Date.today)

    get "/api/v1/leaderboards/podium", params: { kind: "followers_total", window: "all" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 3, json["podium"].size
  end
end
