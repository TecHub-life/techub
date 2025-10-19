require "test_helper"

class LeaderboardsComputeServiceTest < ActiveSupport::TestCase
  test "computes followers_total leaderboard" do
    p1 = Profile.create!(github_id: 1, login: "a", followers: 10)
    p2 = Profile.create!(github_id: 2, login: "b", followers: 20)

    result = Leaderboards::ComputeService.call(kind: "followers_total", window: "all", as_of: Date.today)
    assert result.success?
    lb = result.value
    assert_equal "followers_total", lb.kind
    assert lb.entries.first["login"].in?([ "a", "b" ]) || lb.entries.first[:login].in?([ "a", "b" ])
  end
end
