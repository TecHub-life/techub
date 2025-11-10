module Notifications
  class OpsAlertService < ApplicationService
    DEV_EMAIL_DELIVERY_FLAG = "DEV_OPS_ALERT_EMAILS_ENABLED".freeze

    def initialize(profile:, job:, error_message:, metadata: nil, duration_ms: nil)
      @profile = profile
      @job = job.to_s
      @error_message = error_message.to_s
      @metadata = metadata
      @duration_ms = duration_ms
    end

    def call
      recipients = alert_recipients
      runtime_meta = build_runtime_metadata
      merged_meta = merge_metadata(@metadata, runtime_meta)

      if intercept_dev_delivery?(recipients)
        log_dev_alert(recipients, merged_meta)
        return success(
          :printed_to_stdout,
          metadata: { recipients: recipients, job: job, runtime: runtime_meta }
        )
      end

      return success(:skipped_no_recipients) if recipients.empty?

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

      success(recipients, metadata: { runtime: runtime_meta })
    rescue StandardError => e
      failure(e)
    end

    private
    attr_reader :profile, :job, :error_message, :metadata, :duration_ms

    def intercept_dev_delivery?(recipients)
      return false unless Rails.env.development?
      return false if recipients.empty?
      return false if development_email_override_enabled?

      true
    end

    def development_email_override_enabled?
      return false unless Rails.env.development?

      AppConfig.truthy?(ENV[DEV_EMAIL_DELIVERY_FLAG])
    end

    def log_dev_alert(recipients, metadata)
      label = metadata_label(metadata)
      recipients_list = recipients.join(", ")
      profile_desc = profile_label
      error_desc = error_message.presence || "none"

      Kernel.puts <<~MSG
        [DEV OPS ALERT] job=#{job} profile=#{profile_desc} recipients=#{recipients_list} error=#{error_desc}
        Metadata: #{label}
        Set #{DEV_EMAIL_DELIVERY_FLAG}=true to deliver this notification instead of logging it in development.
      MSG
    end

    def metadata_label(metadata)
      metadata.is_a?(Hash) ? metadata.inspect : metadata.to_s
    end

    def profile_label
      return "@#{profile.login}" if profile&.login.present?
      return "Profile##{profile.id}" if profile&.respond_to?(:id)

      "unknown profile"
    end

    def alert_recipients
      [
        ENV["ALERT_EMAIL"],
        credentials_alert_email
      ].flat_map { |value| normalize_alert_value(value) }
        .map(&:strip)
        .reject(&:blank?)
        .uniq
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

    def credentials_alert_email
      Rails.application.credentials.dig(:mission_control, :jobs, :alert_email)
    rescue StandardError
      nil
    end

    def normalize_alert_value(value)
      case value
      when nil
        []
      when String
        value.split(/[,\s]+/)
      when Array
        value.flat_map { |entry| normalize_alert_value(entry) }
      else
        [ value.to_s ]
      end
    end
  end
end
