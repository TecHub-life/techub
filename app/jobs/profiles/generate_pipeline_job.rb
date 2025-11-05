module Profiles
  class GeneratePipelineJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    def perform(login)
      started = Time.current
      StructuredLogger.info(message: "pipeline_started", service: self.class.name, login: login)
      result = Profiles::GeneratePipelineService.call(login: login)
      profile = Profile.for_login(login).first
      return unless profile

      duration_ms = ((Time.current - started) * 1000).to_i

      if result.success?
        partial = result.degraded?
        status = partial ? "partial_success" : "success"
        profile.update!(last_pipeline_status: status, last_pipeline_error: nil)
        StructuredLogger.info(message: "pipeline_completed", service: self.class.name, login: login, duration_ms: duration_ms, partial: partial)
      else
        profile.update!(last_pipeline_status: "failure", last_pipeline_error: result.error.message)
        StructuredLogger.error(message: "pipeline_failed", service: self.class.name, login: login, error: result.error.message, duration_ms: duration_ms)
      end
    end
  end
end
