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
        languages: { "Ruby" => 3 }
      }

      Github::ProfileSummaryService.stub :call, ServiceResult.success(payload) do
        result = Profiles::SyncFromGithub.call(login: "loftwah")

        assert result.success?
        profile = result.value
        assert_equal "loftwah", profile.github_login
        assert_equal "Sharpest builder", profile.summary
        assert_equal "https://github.com/loftwah.png", profile.avatar_url
      end
    end
  end
end
