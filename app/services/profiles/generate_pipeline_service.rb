require "securerandom"

module Profiles
  class GeneratePipelineService < ApplicationService
    Stage = Struct.new(
      :id,
      :label,
      :service,
      :options,
      :gated_by,
      :description,
      :produces,
      keyword_init: true
    ) do
      def options
        value = self[:options]
        value.nil? ? {} : value
      end

      def produces
        value = self[:produces]
        value.nil? ? [] : value
      end

      def describe
        {
          id: id,
          label: label,
          service: service,
          service_name: service&.name,
          options: options,
          gated_by: gated_by,
          description: description,
          produces: produces
        }
      end
    end

    CORE_VARIANTS = %w[og card simple banner].freeze
    SOCIAL_VARIANTS = Screenshots::CaptureCardService::SOCIAL_VARIANTS.freeze
    SCREENSHOT_VARIANTS = (CORE_VARIANTS + SOCIAL_VARIANTS).uniq.freeze

    FALLBACK_HOSTS = {
      "development" => "http://127.0.0.1:3000",
      "test" => "http://127.0.0.1:3000",
      "production" => "https://techub.life"
    }.freeze

    STAGES = [
      Stage.new(
        id: :pull_github_data,
        label: "Pull GitHub data",
        service: Pipeline::Stages::FetchGithubProfile,
        options: {},
        description: "Fetch GitHub summary payload (with user-token fallback)",
        produces: %w[github_payload]
      ),
      Stage.new(
        id: :download_github_avatar,
        label: "Download GitHub avatar",
        service: Pipeline::Stages::DownloadAvatar,
        options: {},
        description: "Download avatar locally for card usage",
        produces: %w[avatar_local_path]
      ),
      Stage.new(
        id: :store_github_profile,
        label: "Store GitHub data",
        service: Pipeline::Stages::PersistGithubProfile,
        options: {},
        description: "Persist profile, repos, orgs, activity, readme, tags",
        produces: %w[
          profile
          profile_repositories
          profile_organizations
          profile_activity
          profile_readme
        ]
      ),
      Stage.new(
        id: :evaluate_eligibility,
        label: "Evaluate eligibility",
        service: Pipeline::Stages::EvaluateEligibility,
        options: {},
        gated_by: :require_profile_eligibility,
        description: "Optionally block pipeline for low-signal profiles",
        produces: %w[eligibility]
      ),
      Stage.new(
        id: :ingest_submitted_repositories,
        label: "Ingest submitted repositories",
        service: Pipeline::Stages::IngestSubmittedRepositories,
        options: {},
        description: "Include user-submitted repos into signals",
        produces: %w[profile_repositories(submitted)]
      ),
      Stage.new(
        id: :record_submitted_scrape,
        label: "Record submitted scrape",
        service: Pipeline::Stages::RecordSubmittedScrape,
        options: {},
        description: "Optional scrape of a provided URL to augment signals",
        produces: %w[profile_scrapes(optional)]
      ),
      Stage.new(
        id: :generate_ai_profile,
        label: "Generate AI profile",
        service: Pipeline::Stages::GenerateAiProfile,
        options: {},
        gated_by: :ai_text,
        description: "Structured JSON describing bios, stats, vibe, tags, playing card, archetype, spirit animal",
        produces: %w[profile_card]
      ),
      Stage.new(
        id: :capture_card_screenshots,
        label: "Capture card screenshots",
        service: Pipeline::Stages::CaptureScreenshots,
        options: { variants: SCREENSHOT_VARIANTS },
        description: "Enqueue card, OG, banner, simple, and social targets",
        produces: SCREENSHOT_VARIANTS
      ),
      Stage.new(
        id: :optimize_card_images,
        label: "Optimize card images",
        service: Pipeline::Stages::OptimizeScreenshots,
        options: {},
        description: "Run post-processing and upload-ready optimizations for generated images",
        produces: SCREENSHOT_VARIANTS
      )
    ].freeze

    class << self
      def steps
        STAGES.map(&:id)
      end

      def describe
        STAGES.map(&:describe)
      end
    end

    def initialize(login:, host: nil, overrides: {})
      @login = login.to_s.downcase
      @host_override = host
      @overrides = overrides || {}
    end

    def call
      run
    end

    def run
      return failure(StandardError.new("login required"), metadata: { stage: :pipeline }) if login.blank?

      run_id = SecureRandom.uuid
      context = Pipeline::Context.new(login: login, host: resolved_host, run_id: run_id, overrides: overrides)
      @last_known_profile = Profile.for_login(login).first
      context.trace(:pipeline, :started, login: login, host: context.host)
      @pending_pipeline_events = []
      pipeline_started_at = Time.current
      record_pipeline_event(stage: :pipeline, status: "started", started_at: pipeline_started_at)
      log_pipeline(:info, "pipeline_started", run_id: run_id, started_at: pipeline_started_at)

      degraded_steps = []

      STAGES.each do |stage|
        stage_started_at = Time.current
        record_stage_event(stage, status: "started", started_at: stage_started_at)

        result = execute_stage(stage, context)
        stage_duration_ms = elapsed_ms(stage_started_at)
        record_stage_snapshot(context, stage, result, stage_duration_ms)

        if result.failure?
          record_stage_event(stage, status: "failed", started_at: stage_started_at, message: result.error&.message)
          record_pipeline_event(stage: :pipeline, status: "failed", started_at: pipeline_started_at, message: result.error&.message)
          log_pipeline(:error, "pipeline_stage_failed", run_id: run_id, stage: stage.id, error: result.error&.message)
          enriched_failure = attach_pipeline_metadata(
            result,
            context: context,
            run_id: run_id,
            degraded_steps: degraded_steps,
            duration_ms: elapsed_ms(pipeline_started_at)
          )
          flush_pending_events
          return enriched_failure
        end

        if result.degraded?
          degraded_steps << { stage: stage.id, metadata: result.metadata }
          record_stage_event(stage, status: "degraded", started_at: stage_started_at, message: degrade_message(result))
        else
          record_stage_event(stage, status: "completed", started_at: stage_started_at)
        end

        refresh_event_profile(context)
      end

      duration_ms = elapsed_ms(pipeline_started_at)
      context.trace(:pipeline, :completed, card_id: context.result_value[:card_id], duration_ms: duration_ms)
      record_pipeline_event(stage: :pipeline, status: "completed", started_at: pipeline_started_at)
      flush_pending_events
      metadata = pipeline_metadata(
        context: context,
        run_id: run_id,
        duration_ms: duration_ms,
        degraded_steps: degraded_steps
      )
      if degraded_steps.any?
        log_pipeline(:warn, "pipeline_completed_degraded", run_id: run_id, duration_ms: duration_ms, degraded_steps: degraded_steps)
        degraded(context.result_value, metadata: metadata)
      else
        log_pipeline(:info, "pipeline_completed", run_id: run_id, duration_ms: duration_ms)
        success(context.result_value, metadata: metadata)
      end
    rescue StandardError => e
      metadata = { login: login, host: resolved_host }
      if defined?(context) && context
        metadata = metadata.merge(
          trace: context.trace_entries,
          stage_metadata: context.stage_metadata,
          pipeline_snapshot: context.serializable_snapshot
        )
      end
      record_pipeline_event(stage: :pipeline, status: "failed", started_at: pipeline_started_at, message: e.message) if defined?(pipeline_started_at)
      flush_pending_events
      log_pipeline(:error, "pipeline_failed", run_id: run_id, error: e.message) if defined?(run_id)
      failure(e, metadata: metadata)
    end

    private

    attr_reader :login, :host_override, :overrides

    def execute_stage(stage, context)
      result = stage.service.call(context: context, **stage.options)
      if result.failure?
        context.trace(stage.id, :failed, label: stage.label, error: result.error&.message)
        return failure(result.error, metadata: failure_metadata(context, stage, result))
      end

      trace_event = result.degraded? ? :degraded : :succeeded
      context.trace(stage.id, trace_event, label: stage.label, metadata: result.metadata)
      result
    rescue StandardError => e
      context.trace(stage.id, :exception, error: e.message)
      failure(e, metadata: failure_metadata(context, stage))
    end

    def degrade_message(result)
      meta = result.metadata || {}
      meta[:reason] || meta[:message] || (meta[:upstream_error] if meta[:upstream_error].present?) || "degraded"
    rescue StandardError
      "degraded"
    end

    def failure_metadata(context, stage, result = nil)
      {
        stage: stage.id,
        label: stage.label,
        login: login,
        host: context.host,
        trace: context.trace_entries,
        upstream: result&.metadata
      }
    end

    def final_metadata(context)
      {
        login: login,
        host: context.host,
        trace: context.trace_entries,
        stage_metadata: context.stage_metadata,
        pipeline_snapshot: context.serializable_snapshot
      }
    end

    def pipeline_metadata(context:, run_id:, duration_ms:, degraded_steps: [], base: {})
      metadata = final_metadata(context)
      base_hash = base.is_a?(Hash) ? base : {}
      metadata = base_hash.merge(metadata) { |_key, old_val, new_val| old_val.presence || new_val }
      snapshot = metadata[:pipeline_snapshot] || context.serializable_snapshot
      metadata.merge!(
        run_id: run_id,
        duration_ms: duration_ms,
        degraded_steps: degraded_steps.presence,
        github_summary: summarize_github_payload(snapshot[:github_payload])
      )
      metadata.compact
    end

    def attach_pipeline_metadata(result, context:, run_id:, degraded_steps:, duration_ms:)
      metadata = pipeline_metadata(
        context: context,
        run_id: run_id,
        duration_ms: duration_ms,
        degraded_steps: degraded_steps,
        base: result.metadata
      )
      result.with_metadata(metadata)
    end

    def elapsed_ms(started_at)
      return nil unless started_at

      ((Time.current - started_at) * 1000).to_i
    end

    def record_stage_event(stage, status:, started_at:, message: nil)
      record_pipeline_event(stage: stage.id, status: status, started_at: started_at, message: message)
    end

    def record_pipeline_event(stage:, status:, started_at:, message: nil)
      profile = profile_for_events
      unless profile
        store_pending_event(stage: stage, status: status, started_at: started_at, message: message)
        return
      end

      persist_pipeline_event(profile: profile, stage: stage, status: status, started_at: started_at, message: message)
    rescue StandardError => e
      if defined?(StructuredLogger)
        StructuredLogger.warn(
          message: "pipeline_event_record_failed",
          service: self.class.name,
          login: profile&.login || login,
          stage: stage,
          status: status,
          error: e.message
        )
      end
    end

    def truncate_message(message)
      return nil if message.blank?

      msg = message.to_s
      msg.length > 250 ? msg[0, 250] : msg
    end

    def profile_for_events
      return @last_known_profile if defined?(@last_known_profile) && @last_known_profile&.persisted?

      @last_known_profile = Profile.for_login(login).first
    end

    def refresh_event_profile(context)
      profile = context.profile
      if profile.present?
        @last_known_profile = profile
        flush_pending_events
      end
    end

    def store_pending_event(stage:, status:, started_at:, message:)
      @pending_pipeline_events ||= []
      @pending_pipeline_events << {
        stage: stage,
        status: status,
        started_at: started_at,
        message: message
      }
    end

    def flush_pending_events
      return unless @pending_pipeline_events.present?

      profile = profile_for_events
      return unless profile

      pending = @pending_pipeline_events.dup
      @pending_pipeline_events.clear
      pending.each do |event|
        begin
          persist_pipeline_event(
            profile: profile,
            stage: event[:stage],
            status: event[:status],
            started_at: event[:started_at],
            message: event[:message]
          )
        rescue StandardError => e
          StructuredLogger.warn(
            message: "pipeline_event_record_failed",
            service: self.class.name,
            login: profile.login,
            stage: event[:stage],
            status: event[:status],
            error: e.message
          ) if defined?(StructuredLogger)
        end
      end
    end

    def persist_pipeline_event(profile:, stage:, status:, started_at:, message:)
      duration_ms = if started_at && %w[completed failed].include?(status.to_s)
        ((Time.current - started_at) * 1000).to_i
      end

      ProfilePipelineEvent.create!(
        profile_id: profile.id,
        stage: stage.to_s,
        status: status.to_s,
        duration_ms: duration_ms,
        message: truncate_message(message),
        created_at: Time.current
      )
    end

    def record_stage_snapshot(context, stage, result, duration_ms)
      snapshot_value = stage_value_summary(stage.id, context, result)
      context.record_stage_metadata(
        stage.id,
        {
          id: stage.id,
          label: stage.label,
          status: result.status,
          success: result.success?,
          degraded: result.degraded?,
          duration_ms: duration_ms,
          error: result.error&.message,
          metadata: result.metadata,
          value: snapshot_value
        }.compact
      )
    rescue StandardError => e
      StructuredLogger.warn(
        message: "stage_snapshot_failed",
        service: self.class.name,
        login: login,
        stage: stage.id,
        error: e.message
      ) if defined?(StructuredLogger)
    end

    def stage_value_summary(stage_id, context, result)
      case stage_id
      when :pull_github_data
        summarize_github_payload(context.github_payload)
      when :download_github_avatar
        context.avatar_local_path.present? ? { avatar_local_path: context.avatar_local_path } : nil
      when :store_github_profile
        profile = context.profile
        profile ? profile.attributes.slice(*snapshot_profile_keys) : nil
      when :evaluate_eligibility
        context.eligibility
      when :ingest_submitted_repositories, :record_submitted_scrape
        result.metadata
      when :generate_ai_profile
        card_snapshot = if context.card.respond_to?(:attributes)
          context.card.attributes.slice(*snapshot_card_keys)
        end
        metadata = result.metadata || {}
        {
          card: card_snapshot,
          provider: metadata[:provider],
          prompt: metadata[:prompt],
          response_preview: metadata[:response_preview],
          attempts: metadata[:attempts]
        }.compact
      when :capture_card_screenshots
        context.captures.presence
      when :optimize_card_images
        context.optimizations.presence
      else
        result.metadata
      end
    rescue StandardError
      nil
    end

    def summarize_github_payload(payload)
      return nil unless payload.is_a?(Hash)

      profile = payload[:profile] || {}
      {
        login: profile[:login],
        name: profile[:name],
        followers: profile[:followers],
        following: profile[:following],
        public_repos: profile[:public_repos],
        public_gists: profile[:public_gists],
        summary_preview: truncate_text(payload[:summary], 200),
        repositories: {
          top: Array(payload[:top_repositories]).size,
          pinned: Array(payload[:pinned_repositories]).size,
          active: Array(payload[:active_repositories]).size
        },
        organizations: Array(payload[:organizations]).map { |org| org[:login] || org[:name] }.compact
      }.compact
    rescue StandardError
      nil
    end

    def truncate_text(text, length)
      return nil if text.blank?

      str = text.to_s
      str.length > length ? "#{str[0, length]}..." : str
    end

    def snapshot_profile_keys
      Profiles::Pipeline::Context::PROFILE_KEYS
    rescue NameError
      []
    end

    def snapshot_card_keys
      Profiles::Pipeline::Context::CARD_KEYS
    rescue NameError
      []
    end

    def resolved_host
      return @resolved_host if defined?(@resolved_host)

      explicit = host_override.presence || ENV["APP_HOST"].presence
      @resolved_host = if explicit.present?
        explicit
      else
        FALLBACK_HOSTS.fetch(Rails.env, FALLBACK_HOSTS["production"])
      end
    end

    def log_pipeline(level, message, **details)
      payload_details = details.compact
      StructuredLogger.public_send(
        level,
        { message: message, login: login }.merge(payload_details),
        component: "pipeline",
        event: "pipeline.#{message}",
        ops_details: { login: login, steps: self.class.steps }.merge(payload_details)
      )
    end
  end
end
