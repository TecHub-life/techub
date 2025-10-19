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

      runtime_meta = build_runtime_metadata
      merged_meta = merge_metadata(@metadata, runtime_meta)

      recipients.each do |email|
        OpsAlertMailer
          .with(
            to: email,
            profile: profile,
            job: job,
            error_message: error_message,
            metadata: merged_meta,
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
      list.split(/[,
\s]+/).map(&:strip).reject(&:blank?).uniq
    end

    def build_runtime_metadata
      {
        rails_env: Rails.env,
        app_host: ENV["APP_HOST"],
        revision: ENV["APP_REVISION"],
        hostname: (Socket.gethostname rescue nil),
        pid: Process.pid
      }.compact
    end

    def merge_metadata(original, runtime)
      base = original.is_a?(Hash) ? original.dup : {}
      base["runtime"] = runtime
      base
    end
  end
end
