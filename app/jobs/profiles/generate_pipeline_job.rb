module Profiles
  class GeneratePipelineJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    def perform(login, options = {})
      started = Time.current
      normalized_options = normalize_options(options)
      trigger_source = normalized_options[:trigger_source].presence || self.class.name
      overrides = normalized_options[:pipeline_overrides] || {}
      overrides = overrides.deep_symbolize_keys if overrides.respond_to?(:deep_symbolize_keys)
      overrides[:trigger_source] ||= trigger_source

      StructuredLogger.info(
        message: "pipeline_started",
        service: self.class.name,
        login: login,
        trigger: trigger_source,
        overrides: overrides.except(:trigger_source)
      )

      profile = Profile.for_login(login).first
      unless profile
        StructuredLogger.warn(
          message: "pipeline_skipped",
          service: self.class.name,
          login: login,
          reason: "missing_profile",
          trigger: trigger_source
        )
        return
      end

      if profile.unlisted? && !allow_unlisted?(normalized_options)
        StructuredLogger.info(
          message: "pipeline_skipped",
          service: self.class.name,
          login: login,
          reason: "unlisted",
          trigger: trigger_source
        )
        return
      end

      result = Profiles::GeneratePipelineService.call(login: login, overrides: overrides)

      duration_ms = ((Time.current - started) * 1000).to_i

      if result.success?
        partial = result.degraded?
        status = partial ? "partial_success" : "success"
        profile.update!(last_pipeline_status: status, last_pipeline_error: nil)
        StructuredLogger.info(
          message: "pipeline_completed",
          service: self.class.name,
          login: login,
          duration_ms: duration_ms,
          partial: partial,
          trigger: trigger_source
        )
      else
        profile.update!(last_pipeline_status: "failure", last_pipeline_error: result.error.message)
        StructuredLogger.error(
          message: "pipeline_failed",
          service: self.class.name,
          login: login,
          error: result.error.message,
          duration_ms: duration_ms,
          trigger: trigger_source
        )
      end
    end

    private

    def normalize_options(options)
      return {} if options.blank?

      options.respond_to?(:deep_symbolize_keys) ? options.deep_symbolize_keys : options
    rescue StandardError
      {}
    end

    def allow_unlisted?(options)
      return false unless options.is_a?(Hash)
      ActiveModel::Type::Boolean.new.cast(options[:allow_unlisted])
    end
  end
end
