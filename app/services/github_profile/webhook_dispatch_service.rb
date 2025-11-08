module GithubProfile
  class WebhookDispatchService < ApplicationService
    HANDLED_EVENTS = {
      "workflow_run" => "Github::WorkflowRunHandlerJob"
    }.freeze

    def initialize(event:, payload:)
      @event = event
      @payload = payload
    end

    def call
      handler_job = HANDLED_EVENTS[event]

      if handler_job
        handler_job.constantize.perform_later(payload)
        success(:enqueued)
      else
        success(:ignored, metadata: { event: event })
      end
    rescue NameError => e
      failure(e)
    end

    private

    attr_reader :event, :payload
  end
end
