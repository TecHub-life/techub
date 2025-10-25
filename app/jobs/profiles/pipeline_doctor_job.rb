module Profiles
  class PipelineDoctorJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    def perform(login:, host: nil, email: nil, variants: nil)
      started = Time.current
      result = Profiles::PipelineDoctorService.call(login: login, host: host, email: email, variants: variants)
      profile = Profile.for_login(login).first
      if result.success?
        # For successful doctor runs, send an ops report email only when email is supplied
        if email.present?
          Notifications::OpsAlertService.call(
            profile: profile,
            job: self.class.name,
            error_message: nil,
            metadata: result.value,
            duration_ms: ((Time.current - started) * 1000).to_i
          )
        end
      else
        Notifications::OpsAlertService.call(
          profile: profile,
          job: self.class.name,
          error_message: result.error&.message,
          metadata: result.respond_to?(:metadata) ? result.metadata : nil,
          duration_ms: ((Time.current - started) * 1000).to_i
        )
        raise result.error || StandardError.new("pipeline_doctor_failed")
      end
    end
  end
end
