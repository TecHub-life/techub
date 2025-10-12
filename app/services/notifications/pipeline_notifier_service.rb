module Notifications
  class PipelineNotifierService < ApplicationService
    def initialize(profile:, status:, error_message: nil)
      @profile = profile
      @status = status.to_s
      @error_message = error_message
    end

    def call
      owners = profile.owners
      results = owners.map do |user|
        Notifications::DeliverOnceService.call(user: user, event: event_name, subject: profile) do
          if status == "success"
            ProfilePipelineMailer.with(user: user, profile: profile).completed.deliver_later
          else
            ProfilePipelineMailer.with(user: user, profile: profile, error_message: error_message || "unknown").failed.deliver_later
          end
        end
      end
      success(results)
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
