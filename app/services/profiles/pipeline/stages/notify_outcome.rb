module Profiles
  module Pipeline
    module Stages
      class NotifyOutcome < BaseStage
        STAGE_ID = :notify_pipeline_outcome

        def call
          outcome = normalized_outcome
          status = outcome[:status]
          profile = context.profile || Profile.for_login(login).first

          if profile.blank?
            trace(:skipped, reason: "profile_missing")
            return success_with_context(nil, metadata: { skipped: true, reason: "profile_missing" })
          end

          notifications = {}

          notifier_result = deliver_pipeline_notification(profile, status, outcome[:error_message])
          notifications[:pipeline] = notifier_result if notifier_result.present?

          ops_result = deliver_ops_alert(profile, status, outcome)
          notifications[:ops] = ops_result if ops_result.present?

          trace(:completed, status: status, notifications: notifications.compact, run_id: outcome[:run_id])
          success_with_context(
            notifications,
            metadata: {
              status: status,
              run_id: outcome[:run_id],
              duration_ms: outcome[:duration_ms],
              notifications: notifications.compact
            }.compact
          )
        rescue StandardError => e
          trace(:failed, error: e.message)
          failure_with_context(e)
        end

        private

        def normalized_outcome
          outcome = context.pipeline_outcome || {}
          status = outcome[:status].to_s.presence || "unknown"
          unless %w[success partial failure].include?(status)
            status = outcome[:degraded_steps].to_a.any? ? "partial" : "success"
          end
          {
            status: status,
            run_id: outcome[:run_id],
            duration_ms: outcome[:duration_ms],
            degraded_steps: outcome[:degraded_steps],
            metadata: outcome[:metadata],
            error_message: outcome[:error].presence || outcome[:error_message]
          }
        end

        def deliver_pipeline_notification(profile, status, error_message)
          return nil unless defined?(Notifications::PipelineNotifierService)

          result = Notifications::PipelineNotifierService.call(
            profile: profile,
            status: status,
            error_message: error_message
          )

          if result.failure?
            raise result.error || StandardError.new("pipeline_notifier_failed")
          end

          { status: result.value }
        end

        def deliver_ops_alert(profile, status, outcome)
          return nil unless defined?(Notifications::OpsAlertService)

          needs_ops = %w[partial failure].include?(status)
          return nil unless needs_ops

          metadata = outcome[:metadata]
          duration_ms = outcome[:duration_ms]
          error_message = outcome[:error_message]
          message = status == "partial" ? "pipeline completed with partials" : (error_message.presence || "pipeline_failed")

          result = Notifications::OpsAlertService.call(
            profile: profile,
            job: "Profiles::GeneratePipelineService",
            error_message: message,
            metadata: metadata,
            duration_ms: duration_ms
          )

          if result.failure?
            raise result.error || StandardError.new("ops_alert_failed")
          end

          { recipients: result.value }
        end
      end
    end
  end
end
