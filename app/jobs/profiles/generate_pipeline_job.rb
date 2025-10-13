module Profiles
  class GeneratePipelineJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    def perform(login, ai: true)
      started = Time.current
      StructuredLogger.info(message: "pipeline_started", service: self.class.name, login: login)
      result = Profiles::GeneratePipelineService.call(login: login, ai: ai)
      profile = Profile.for_login(login).first
      return unless profile

      if result.success?
        profile.update!(last_pipeline_status: "success", last_pipeline_error: nil)
        Notifications::PipelineNotifierService.call(profile: profile, status: "success")
        StructuredLogger.info(message: "pipeline_completed", service: self.class.name, login: login, duration_ms: ((Time.current - started) * 1000).to_i)
      else
        profile.update!(last_pipeline_status: "failure", last_pipeline_error: result.error.message)
        Notifications::PipelineNotifierService.call(profile: profile, status: "failure", error_message: result.error.message)
        StructuredLogger.error(message: "pipeline_failed", service: self.class.name, login: login, error: result.error.message, duration_ms: ((Time.current - started) * 1000).to_i)
      end
    end
  end
end
