module Github
  class WorkflowRunHandlerJob < ApplicationJob
    queue_as :default

    def perform(payload)
      Rails.logger.info(payload: payload, message: "Received workflow_run event")
    end
  end
end
