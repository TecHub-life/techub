require "test_helper"

module GithubProfile
  class WebhookDispatchServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    test "enqueues workflow run handler" do
      payload = { "workflow_run" => {} }

      assert_enqueued_with(job: Github::WorkflowRunHandlerJob, args: [ payload ]) do
        result = GithubProfile::WebhookDispatchService.call(event: "workflow_run", payload: payload)
        assert result.success?
      end
    end

    test "ignores unsupported events" do
      result = GithubProfile::WebhookDispatchService.call(event: "push", payload: {})

      assert result.success?
      assert_equal :ignored, result.value
    end
  end
end
