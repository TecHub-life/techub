require "test_helper"

module Notifications
  class OpsAlertServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      clear_enqueued_jobs
      @profile = Profile.create!(
        github_id: unique_github_id,
        login: unique_login
      )
    end

    teardown do
      clear_enqueued_jobs
      ENV.delete("ALERT_EMAIL")
      ENV.delete(OpsAlertService::DEV_EMAIL_DELIVERY_FLAG)
    end

    test "development prints alerts to stdout unless the dev flag is flipped" do
      ENV["ALERT_EMAIL"] = "ops@example.com"

      Rails.env.stub(:development?, true) do
        assert_output(/\[DEV OPS ALERT\]/) do
          assert_no_enqueued_jobs do
            result = OpsAlertService.call(
              profile: @profile,
              job: "TestJob",
              error_message: "boom",
              metadata: { step: "dev" },
              duration_ms: 42
            )

            assert result.success?
            assert_equal :printed_to_stdout, result.value
            assert_includes result.metadata[:recipients], "ops@example.com"
          end
        end
      end
    end

    test "development flag re-enables emailing so jobs get enqueued" do
      ENV["ALERT_EMAIL"] = "ops@example.com"
      ENV[OpsAlertService::DEV_EMAIL_DELIVERY_FLAG] = "true"

      Rails.env.stub(:development?, true) do
        assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
          OpsAlertService.call(
            profile: @profile,
            job: "TestJob",
            error_message: "boom",
            metadata: { step: "dev" },
            duration_ms: 42
          )
        end
      end
    end

    test "supports array of recipients from credentials" do
      Rails.application.credentials.stub(:dig, ["ops@example.com", "ops2@example.com"]) do
        Rails.env.stub(:development?, true) do
          assert_output(/\[DEV OPS ALERT\]/) do
            result = OpsAlertService.call(
              profile: @profile,
              job: "TestJob",
              error_message: "boom",
              metadata: { step: "dev" },
              duration_ms: 42
            )

            assert result.success?
            recipients = result.metadata[:recipients]
            assert_includes recipients, "ops@example.com"
            assert_includes recipients, "ops2@example.com"
          end
        end
      end
    end
  end
end
