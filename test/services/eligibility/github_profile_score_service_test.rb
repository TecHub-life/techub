require "test_helper"

module Eligibility
  class GithubProfileScoreServiceTest < ActiveSupport::TestCase
    setup do
      @as_of = Time.zone.parse("2025-01-01")
    end

    test "returns eligible when all signals pass" do
      travel_to @as_of do
        profile = {
          login: "loftwah",
          created_at: 120.days.ago.iso8601,
          followers: 5,
          following: 1,
          bio: "DevOps engineer"
        }

        repositories = [
          repo_for("loftwah/alpha", pushed_at: 2.months.ago, private: false, archived: false),
          repo_for("loftwah/bravo", pushed_at: 3.months.ago, private: false, archived: false),
          repo_for("loftwah/charlie", pushed_at: 5.months.ago, private: false, archived: false)
        ]

        recent_activity = { total_events: 10 }
        pinned_repositories = [ { name: "alpha" } ]

        result = Eligibility::GithubProfileScoreService.call(
          profile: profile,
          repositories: repositories,
          recent_activity: recent_activity,
          pinned_repositories: pinned_repositories,
          profile_readme: nil,
          as_of: @as_of
        )

        assert result.success?
        assert_equal 5, result.value[:score]
        assert result.value[:eligible]
        assert result.value[:signals].values.all? { |signal| signal[:met] }
      end
    end

    test "flags account age when the profile is too new" do
      travel_to @as_of do
        profile = {
          login: "newbie",
          created_at: 10.days.ago.iso8601,
          followers: 10,
          following: 10,
          bio: "Enthusiastic builder"
        }

        repositories = Array.new(3) { |i| repo_for("newbie/repo#{i}", pushed_at: 1.month.ago, private: false, archived: false) }
        recent_activity = { total_events: 10 }

        result = Eligibility::GithubProfileScoreService.call(
          profile: profile,
          repositories: repositories,
          recent_activity: recent_activity,
          as_of: @as_of
        )

        assert result.success?
        refute result.value[:signals][:account_age][:met]
        assert_match(/below minimum/, result.value[:signals][:account_age][:detail])
        assert result.value[:eligible], "Other signals should still make the profile eligible"
      end
    end

    test "ignores private, archived, or stale repositories" do
      travel_to @as_of do
        profile = {
          "login" => "loftwah",
          "created_at" => 2.years.ago.iso8601,
          "followers" => 4,
          "following" => 0,
          "bio" => ""
        }

        repositories = [
          repo_for("loftwah/alpha", pushed_at: 13.months.ago, private: false, archived: false),
          repo_for("loftwah/bravo", pushed_at: 1.month.ago, private: true, archived: false),
          repo_for("loftwah/charlie", pushed_at: 1.month.ago, private: false, archived: true),
          repo_for("techteam/delta", pushed_at: 1.month.ago, private: false, archived: false, owner_login: "TechTeam")
        ]

        organizations = [ { login: "TecHub-life" } ]
        recent_activity = { "total_events" => 3 }
        pinned_repositories = []
        profile_readme = "## README"

        result = Eligibility::GithubProfileScoreService.call(
          profile: profile,
          repositories: repositories,
          recent_activity: recent_activity,
          pinned_repositories: pinned_repositories,
          profile_readme: profile_readme,
          organizations: organizations,
          as_of: @as_of
        )

        assert result.success?
        refute result.value[:signals][:repository_activity][:met]
        assert_match(/Only 0 public repos/, result.value[:signals][:repository_activity][:detail])
        refute result.value[:signals][:recent_activity][:met]
        assert result.value[:signals][:meaningful_profile][:met], "README should count as context"
        assert result.value[:eligible], "Other signals keep the score above the threshold"
      end
    end

    test "declines when fewer than three signals pass" do
      travel_to @as_of do
        profile = {
          login: "ghost",
          created_at: 40.days.ago.iso8601,
          followers: 0,
          following: 0,
          bio: ""
        }

        repositories = [
          repo_for("ghost/abandoned", pushed_at: 3.years.ago, private: false, archived: false)
        ]

        recent_activity = { total_events: 0 }

        result = Eligibility::GithubProfileScoreService.call(
          profile: profile,
          repositories: repositories,
          recent_activity: recent_activity,
          pinned_repositories: [],
          profile_readme: nil,
          as_of: @as_of
        )

        assert result.success?
        assert_equal 0, result.value[:score]
        refute result.value[:eligible]
      end
    end

    private

    def repo_for(full_name, pushed_at:, private:, archived:, owner_login: nil)
      owner_login ||= full_name.split("/").first
      {
        name: full_name.split("/").last,
        full_name: full_name,
        pushed_at: pushed_at.iso8601,
        private: private,
        archived: archived,
        owner: { login: owner_login }
      }
    end
  end
end
