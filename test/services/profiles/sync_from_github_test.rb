require "test_helper"

module Profiles
  class SyncFromGithubTest < ActiveSupport::TestCase
    test "creates or updates profile from github payload" do
      payload = {
        profile: {
          id: 1,
          login: "loftwah",
          name: "Dean Lofts",
          avatar_url: "https://github.com/loftwah.png"
        },
        summary: "Sharpest builder",
        top_repositories: [],
        pinned_repositories: [],
        active_repositories: [],
        organizations: [],
        social_accounts: [],
        languages: { "Ruby" => 3 },
        profile_readme: nil,
        recent_activity: nil
      }

      Github::ProfileSummaryService.stub :call, ServiceResult.success(payload) do
        # Avoid real HTTP for avatar download during test
        Github::DownloadAvatarService.stub :call, ServiceResult.success("/avatars/loftwah.png") do
        result = Profiles::SyncFromGithub.call(login: "loftwah")

        assert result.success?
        profile = result.value
        assert_equal "loftwah", profile.login
        assert_equal "Sharpest builder", profile.summary
        # Avatar should be either the local path or the GitHub URL (depending on download success)
        assert_match(/loftwah\.png$/, profile.avatar_url)
        end
      end
    end
  end
end
