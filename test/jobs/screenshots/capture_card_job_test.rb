require "test_helper"

class CaptureCardJobTest < ActiveJob::TestCase
  test "enqueues and records asset on success" do
    profile = Profile.create!(github_id: 808, login: "loftwah")

    # Stub capture service to return a fake path
    Screenshots::CaptureCardService.stub :call, ServiceResult.success({ output_path: "public/generated/loftwah/og.png", mime_type: "image/png", width: 1200, height: 630 }) do
      assert_difference -> { ProfilePipelineEvent.count }, +2 do
        assert_enqueued_with(job: Screenshots::CaptureCardJob) do
          Screenshots::CaptureCardJob.perform_later(login: profile.login, variant: "og", host: "http://127.0.0.1:3000")
        end

        perform_enqueued_jobs
      end

      asset = profile.profile_assets.find_by(kind: "og")
      assert asset
      assert_equal "image/png", asset.mime_type
      assert_equal 1200, asset.width
      assert_equal 630, asset.height

      events = profile.profile_pipeline_events.where(stage: "screenshot_og").order(:created_at)
      assert_equal 2, events.size
      assert_equal "started", events.first.status
      assert_equal "completed", events.last.status
    end
  end
end
