module Notifications
  class PipelineNotifierService < ApplicationService
    def initialize(profile:, status:, error_message: nil)
      @profile = profile
      @status = status.to_s
      @error_message = error_message
    end

    def call
      case status
      when "success"
        owners = profile.owners
        results = owners.map do |user|
          Notifications::DeliverOnceService.call(user: user, event: event_name, subject: profile) do
            ProfilePipelineMailer.with(user: user, profile: profile).completed.deliver_later
          end
        end
        success(results)
      when "partial"
        # No user emails for partial; handled upstream by OpsAlertService
        success(:partial_notified_ops)
      else
        owners = profile.owners
        results = owners.map do |user|
          Notifications::DeliverOnceService.call(user: user, event: event_name, subject: profile) do
            ProfilePipelineMailer.with(user: user, profile: profile, error_message: error_message || "unknown").failed.deliver_later
          end
        end
        success(results)
      end
    rescue StandardError => e
      failure(e)
    end

    private
    attr_reader :profile, :status, :error_message

    def event_name
      status == "success" ? "pipeline_completed" : "pipeline_failed"
    end
  end
end
