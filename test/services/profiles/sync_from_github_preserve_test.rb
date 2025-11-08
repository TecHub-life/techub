require "test_helper"

module Profiles
  class SyncFromGithubPreserveTest < ActiveSupport::TestCase
    test "preserves existing scalars when payload fields are nil" do
      profile = Profile.create!(github_id: 10001, login: "loftwah", name: "Dean", bio: "bio1", company: "Co", followers: 10)

      payload = {
        profile: {
          id: profile.github_id,
          login: profile.login,
          name: nil,
          bio: nil,
          company: nil,
          followers: nil
        }
        # omit sections entirely to test no-association rebuild
      }

      GithubProfile::ProfileSummaryService.stub :call, ServiceResult.success(payload) do
        GithubProfile::DownloadAvatarService.stub :call, ServiceResult.failure(StandardError.new("skip")) do
          result = Profiles::SyncFromGithub.call(login: profile.login)
          assert result.success?
          p2 = result.value.reload
          assert_equal "Dean", p2.name
          assert_equal "bio1", p2.bio
          assert_equal "Co", p2.company
          assert_equal 10, p2.followers
        end
      end
    end

    test "does not rebuild associations when sections are missing" do
      profile = Profile.create!(github_id: 10002, login: "builder")
      # seed associations
      profile.profile_organizations.create!(login: "acme", name: "ACME")
      profile.profile_languages.create!(name: "Ruby", count: 10)
      profile.profile_repositories.create!(name: "top1", full_name: "builder/top1", repository_type: "top")
      profile.create_profile_activity!(total_events: 5)

      payload = {
        profile: { id: profile.github_id, login: profile.login }
        # no organizations/languages/repos/recent_activity keys
      }

      GithubProfile::ProfileSummaryService.stub :call, ServiceResult.success(payload) do
        GithubProfile::DownloadAvatarService.stub :call, ServiceResult.failure(StandardError.new("skip")) do
          result = Profiles::SyncFromGithub.call(login: profile.login)
          assert result.success?
          p2 = result.value.reload
          assert_equal 1, p2.profile_organizations.count
          assert_equal 1, p2.profile_languages.count
          assert_equal 1, p2.profile_repositories.where(repository_type: "top").count
          assert p2.profile_activity.present?
        end
      end
    end
  end
end
