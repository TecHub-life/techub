require "test_helper"

module Profiles
  class SubmitProfileJobTest < ActiveJob::TestCase
    test "uses ai:true only on first creation (no card, no ai regenerated)" do
      user = User.create!(github_id: 777, login: "owner")
      payload = { profile: { id: 7001, login: "firstrun", avatar_url: "https://example.com/a.png" } }

      Github::ProfileSummaryService.stub :call, ServiceResult.success(payload) do
        Github::DownloadAvatarService.stub :call, ServiceResult.success("/avatars/firstrun.png") do
          assert_enqueued_with(job: Profiles::GeneratePipelineJob, args: [ "firstrun", { ai: true } ]) do
            Profiles::SubmitProfileJob.perform_now("firstRun", user.id)
          end
        end
      end
    end

    test "uses ai:false on subsequent submissions when card exists or ai was regenerated" do
      user = User.create!(github_id: 778, login: "owner2")
      prof = Profile.create!(github_id: 7002, login: "second")
      prof.create_profile_card!(attack: 10, defense: 10, speed: 10, tags: [ "ruby", "rails", "oss", "devops", "linux", "cloud" ]) rescue nil
      prof.update_columns(last_ai_regenerated_at: Time.current)

      Github::ProfileSummaryService.stub :call, ServiceResult.success({ profile: { id: prof.github_id, login: prof.login, avatar_url: "https://example.com/b.png" } }) do
        Github::DownloadAvatarService.stub :call, ServiceResult.success("/avatars/second.png") do
          assert_enqueued_with(job: Profiles::GeneratePipelineJob, args: [ "second", { ai: false } ]) do
            Profiles::SubmitProfileJob.perform_now("second", user.id)
          end
        end
      end
    end
  end
end
