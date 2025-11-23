require "test_helper"

module Profiles
  class SubmitProfileJobTest < ActiveJob::TestCase
    test "enqueues pipeline on first submission" do
      user = User.create!(github_id: 777, login: "owner")
      payload = { profile: { id: 7001, login: "firstrun", avatar_url: "https://example.com/a.png" } }

      GithubProfile::ProfileSummaryService.stub :call, ServiceResult.success(payload) do
        GithubProfile::DownloadAvatarService.stub :call, ServiceResult.success("/avatars/firstrun.png") do
          assert_enqueued_with(job: Profiles::GeneratePipelineJob, args: [ "firstrun", { trigger_source: "submit_profile_job" } ]) do
            Profiles::SubmitProfileJob.perform_now("firstRun", user.id)
          end
        end
      end
    end

    test "enqueues pipeline on subsequent submissions" do
      user = User.create!(github_id: 778, login: "owner2")
      prof = Profile.create!(github_id: 7002, login: "second")
      prof.update_columns(last_ai_regenerated_at: Time.current)

      GithubProfile::ProfileSummaryService.stub :call, ServiceResult.success({ profile: { id: prof.github_id, login: prof.login, avatar_url: "https://example.com/b.png" } }) do
        GithubProfile::DownloadAvatarService.stub :call, ServiceResult.success("/avatars/second.png") do
          assert_enqueued_with(job: Profiles::GeneratePipelineJob, args: [ "second", { trigger_source: "submit_profile_job" } ]) do
            Profiles::SubmitProfileJob.perform_now("second", user.id)
          end
        end
      end
    end

    test "normalizes submitted repositories from URLs" do
      user = User.create!(github_id: 779, login: "owner3")
      payload = { profile: { id: 7003, login: "url-tester", avatar_url: "https://example.com/c.png" } }

      GithubProfile::ProfileSummaryService.stub :call, ServiceResult.success(payload) do
        GithubProfile::DownloadAvatarService.stub :call, ServiceResult.success("/avatars/url-tester.png") do
          Profiles::SubmitProfileJob.perform_now(
            "url-tester",
            user.id,
            submitted_repositories: [
              "https://github.com/owner/repo1",
              "http://github.com/owner/repo2",
              "github.com/owner/repo3",
              "owner/repo4",
              "invalid-repo-format"
            ]
          )
        end
      end

      profile = Profile.find_by(login: "url-tester")
      repos = profile.profile_repositories.where(repository_type: "submitted").pluck(:full_name)

      assert_includes repos, "owner/repo1"
      assert_includes repos, "owner/repo2"
      assert_includes repos, "owner/repo3"
      assert_includes repos, "owner/repo4"
      refute_includes repos, "invalid-repo-format"
    end
  end
end
