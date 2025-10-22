module Profiles
  class GeneratePipelineJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    # images: controls AI image generation; text AI always runs.
    # ai: legacy alias for images (deprecated)
    def perform(login, images: true, ai: nil)
      started = Time.current
      StructuredLogger.info(message: "pipeline_started", service: self.class.name, login: login)
      images_flag = images.nil? ? ai : images
      result = Profiles::GeneratePipelineService.call(login: login, images: images_flag)
      profile = Profile.for_login(login).first
      return unless profile

      if result.success?
        partial = result.respond_to?(:metadata) && (result.metadata || {})[:partial]
        status = partial ? "partial_success" : "success"
        profile.update!(last_pipeline_status: status, last_pipeline_error: nil)
        Notifications::PipelineNotifierService.call(profile: profile, status: "success")
        StructuredLogger.info(message: "pipeline_completed", service: self.class.name, login: login, duration_ms: ((Time.current - started) * 1000).to_i, partial: partial)
      else
        profile.update!(last_pipeline_status: "failure", last_pipeline_error: result.error.message)
        Notifications::PipelineNotifierService.call(profile: profile, status: "failure", error_message: result.error.message)
        # Ops alert for failed pipeline runs (env/credentials driven)
        Notifications::OpsAlertService.call(
          profile: profile,
          job: self.class.name,
          error_message: result.error.message,
          metadata: result.respond_to?(:metadata) ? result.metadata : nil,
          duration_ms: ((Time.current - started) * 1000).to_i
        )
        StructuredLogger.error(message: "pipeline_failed", service: self.class.name, login: login, error: result.error.message, duration_ms: ((Time.current - started) * 1000).to_i)
      end
    end
  end
end
