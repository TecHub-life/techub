module Notifications
  class OpsAlertService < ApplicationService
    def initialize(profile:, job:, error_message:, metadata: nil, duration_ms: nil)
      @profile = profile
      @job = job.to_s
      @error_message = error_message.to_s
      @metadata = metadata
      @duration_ms = duration_ms
    end

    def call
      recipients = alert_recipients
      return success(:skipped_no_recipients) if recipients.empty?

      recipients.each do |email|
        OpsAlertMailer
          .with(
            to: email,
            profile: profile,
            job: job,
            error_message: error_message,
            metadata: metadata,
            duration_ms: duration_ms
          )
          .job_failed
          .deliver_later
      end

      success(recipients)
    rescue StandardError => e
      failure(e)
    end

    private
    attr_reader :profile, :job, :error_message, :metadata, :duration_ms

    def alert_recipients
      env = ENV["ALERT_EMAIL"].to_s.strip
      creds = (Rails.application.credentials.dig(:mission_control, :jobs, :alert_email) rescue nil).to_s.strip

      list = [ env, creds ].reject(&:blank?).join(",")
      list.split(/[,\s]+/).map(&:strip).reject(&:blank?).uniq
    end
  end
end
