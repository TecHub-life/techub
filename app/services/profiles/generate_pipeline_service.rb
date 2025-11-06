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

    CORE_VARIANTS = %w[og og_pro card card_pro simple banner].freeze
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
        description: "Fetch GitHub profile + repos via Github::ProfileSummaryService (user token first, app token fallback); stores raw payload on the pipeline context for downstream stages.",
        produces: %w[github_payload]
      ),
      Stage.new(
        id: :download_github_avatar,
        label: "Download GitHub avatar",
        service: Pipeline::Stages::DownloadAvatar,
        options: {},
        description: "Download current avatar image into /public/avatars; records absolute + relative paths for upload and rendering.",
        produces: %w[avatar_local_path]
      ),
      Stage.new(
        id: :upload_github_avatar,
        label: "Upload avatar to storage",
        service: Pipeline::Stages::UploadAvatar,
        options: {},
        description: "Push downloaded avatar to configured Active Storage (DO Spaces) and cache public URL for later persistence.",
        produces: %w[avatar_public_url]
      ),
      Stage.new(
        id: :store_github_profile,
        label: "Store GitHub data",
        service: Pipeline::Stages::PersistGithubProfile,
        options: {},
        description: "Persist profile attributes, repos, orgs, social accounts, languages, activity, readme, and avatar path into the database inside a transaction.",
        produces: %w[
          profile
          profile_repositories
          profile_organizations
          profile_activity
          profile_readme
        ]
      ),
      Stage.new(
        id: :record_avatar_asset,
        label: "Record avatar asset",
        service: Pipeline::Stages::RecordAvatarAsset,
        options: {},
        description: "Create/update ProfileAsset entry for the current avatar (local path + Spaces URL) so Ops tooling sees the latest source.",
        produces: %w[profile_assets(avatar)]
      ),
      Stage.new(
        id: :evaluate_eligibility,
        label: "Evaluate eligibility",
        service: Pipeline::Stages::EvaluateEligibility,
        options: {},
        gated_by: :require_profile_eligibility,
        description: "Calls Eligibility::GithubProfileScoreService to score the profile; aborts pipeline when eligibility flag requires a passing score.",
        produces: %w[eligibility]
      ),
      Stage.new(
        id: :ingest_submitted_repositories,
        label: "Ingest submitted repositories",
        service: Pipeline::Stages::IngestSubmittedRepositories,
        options: {},
        description: "Merge user-submitted repositories into ProfileRepository records so downstream scoring/screenshots see the augmented set.",
        produces: %w[profile_repositories(submitted)]
      ),
      Stage.new(
        id: :record_submitted_scrape,
        label: "Record submitted scrape",
        service: Pipeline::Stages::RecordSubmittedScrape,
        options: {},
        description: "Persist optional scraped URL details into associated scrape records; captures any uploaded assets referenced in the scrape payload.",
        produces: %w[profile_scrapes(optional)]
      ),
      Stage.new(
        id: :generate_ai_profile,
        label: "Generate AI profile",
        service: Pipeline::Stages::GenerateAiProfile,
        options: {},
        gated_by: :ai_text,
        description: "Produce or reuse ProfileCard JSON via Gemini / SynthesizeAiProfileService with overrides and heuristics fallback; persists card fields (stats, copy, prompts) to the database.",
        produces: %w[profile_card]
      ),
      Stage.new(
        id: :capture_card_screenshots,
        label: "Capture card screenshots",
        service: Pipeline::Stages::CaptureScreenshots,
        options: { variants: SCREENSHOT_VARIANTS },
        description: "Render card/OG/social variants via Screenshots::CaptureCardJob (Puppeteer); saves images locally and, when configured, uploads to DO Spaces/Active Storage.",
        produces: SCREENSHOT_VARIANTS
      ),
      Stage.new(
        id: :optimize_card_images,
        label: "Optimize card images",
        service: Pipeline::Stages::OptimizeScreenshots,
        options: {},
        description: "Run Images::OptimizeJob on each capture to compress/rewrite bytes and optionally replace uploads in Spaces so downstream shares use the optimized asset.",
        produces: SCREENSHOT_VARIANTS
      ),
      Stage.new(
        id: :notify_pipeline_outcome,
        label: "Notify stakeholders",
        service: Pipeline::Stages::NotifyOutcome,
        options: {},
        description: "Deliver pipeline completion notifications to profile owners and ops (success/partial/failure) with run metadata.",
        produces: %w[notifications]
      )
    ].freeze

    class << self
      def steps
        STAGES.map(&:id)
      end

      def describe
        STAGES.map(&:describe)
      end

      def stage_with_id(id)
        STAGES.find { |stage| stage.id == id.to_sym }
      end
    end

    def initialize(login:, host: nil, overrides: {})
      @login = login.to_s.downcase
      @host_override = host
      @overrides = normalize_overrides(overrides)
      @skip_stages = Array(@overrides[:skip_stages]).map { |s| s.to_sym rescue nil }.compact.uniq
      @only_stages = Array(@overrides[:only_stages]).map { |s| s.to_sym rescue nil }.compact.uniq
      @trigger_source = extract_trigger_source(@overrides)
    end

    def call
      run
    end

    def run
      return failure(StandardError.new("login required"), metadata: { stage: :pipeline }) if login.blank?

      run_id = SecureRandom.uuid
      context = Pipeline::Context.new(login: login, host: resolved_host, run_id: run_id, overrides: overrides)
      context.degraded_steps = []
      @last_known_profile = Profile.for_login(login).first
      context.trace(:pipeline, :started, login: login, host: context.host, trigger: trigger_source)
      @pending_pipeline_events = []
      pipeline_started_at = Time.current
      record_pipeline_event(stage: :pipeline, status: "started", started_at: pipeline_started_at)
      log_pipeline(:info, "pipeline_started", run_id: run_id, started_at: pipeline_started_at)

      degraded_steps = []

      STAGES.each do |stage|
        if skip_stage?(stage.id)
          skip_started_at = Time.current
          context.trace(stage.id, :skipped, reason: "skipped_via_override", trigger: trigger_source)
          record_stage_event(stage, status: "skipped", started_at: skip_started_at, message: "skipped_via_override")
          next
        end

        if stage.id == :notify_pipeline_outcome
          snapshot_duration_ms = elapsed_ms(pipeline_started_at)
          snapshot_metadata = pipeline_metadata(
            context: context,
            run_id: run_id,
            duration_ms: snapshot_duration_ms,
            degraded_steps: degraded_steps
          )
          context.degraded_steps = degraded_steps.dup
          context.pipeline_metadata = snapshot_metadata
          context.pipeline_outcome = {
            status: degraded_steps.any? ? :partial : :success,
            run_id: run_id,
            duration_ms: snapshot_duration_ms,
            degraded_steps: degraded_steps,
            metadata: snapshot_metadata,
            error: nil,
            trigger: trigger_source
          }
        end
        stage_started_at = Time.current
        record_stage_event(stage, status: "started", started_at: stage_started_at)

        result = execute_stage(stage, context)
        stage_duration_ms = elapsed_ms(stage_started_at)
        record_stage_snapshot(context, stage, result, stage_duration_ms)

        if result.failure?
          record_stage_event(stage, status: "failed", started_at: stage_started_at, message: result.error&.message)
          record_pipeline_event(stage: :pipeline, status: "failed", started_at: pipeline_started_at, message: result.error&.message)
          log_pipeline(:error, "pipeline_stage_failed", run_id: run_id, stage: stage.id, error: result.error&.message)
          failure_duration_ms = elapsed_ms(pipeline_started_at)
          if stage.id != :notify_pipeline_outcome
            context.degraded_steps = degraded_steps.dup
            perform_notification_stage(
              status: :failure,
              context: context,
              run_id: run_id,
              pipeline_started_at: pipeline_started_at,
              degraded_steps: degraded_steps,
              error: result.error&.message
            )
          end
          failure_metadata = pipeline_metadata(
            context: context,
            run_id: run_id,
            duration_ms: failure_duration_ms,
            degraded_steps: degraded_steps
          )
          context.pipeline_metadata = failure_metadata
          context.pipeline_outcome = {
            status: :failure,
            run_id: run_id,
            duration_ms: failure_duration_ms,
            degraded_steps: degraded_steps,
            metadata: failure_metadata,
            error: result.error&.message,
            trigger: trigger_source
          }
          enriched_failure = attach_pipeline_metadata(
            result,
            context: context,
            run_id: run_id,
            degraded_steps: degraded_steps,
            duration_ms: failure_duration_ms
          )
          flush_pending_events
          return enriched_failure
        end

        if result.degraded?
          degraded_steps << { stage: stage.id, metadata: result.metadata }
          context.degraded_steps = degraded_steps.dup
          record_stage_event(stage, status: "degraded", started_at: stage_started_at, message: degrade_message(result))
        else
          record_stage_event(stage, status: "completed", started_at: stage_started_at)
        end

        refresh_event_profile(context)
        context.degraded_steps = degraded_steps.dup
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
      context.pipeline_metadata = metadata
      context.pipeline_outcome = {
        status: degraded_steps.any? ? :partial : :success,
        run_id: run_id,
        duration_ms: duration_ms,
        degraded_steps: degraded_steps,
        metadata: metadata,
        error: nil,
        trigger: trigger_source
      }
      if degraded_steps.any?
        log_pipeline(:warn, "pipeline_completed_degraded", run_id: run_id, duration_ms: duration_ms, degraded_steps: degraded_steps)
        degraded(context.result_value, metadata: metadata)
      else
        log_pipeline(:info, "pipeline_completed", run_id: run_id, duration_ms: duration_ms)
        success(context.result_value, metadata: metadata)
      end
    rescue StandardError => e
      degraded_snapshot = []
      if defined?(context) && context
        degraded_snapshot = context.degraded_steps || []
        if defined?(run_id) && defined?(pipeline_started_at)
          perform_notification_stage(
            status: :failure,
            context: context,
            run_id: run_id,
            pipeline_started_at: pipeline_started_at,
            degraded_steps: degraded_snapshot,
            error: e.message
          )
        end
      end

      metadata = { login: login, host: resolved_host, trigger: trigger_source }
      if defined?(context) && context
        duration_ms = defined?(pipeline_started_at) ? elapsed_ms(pipeline_started_at) : nil
        failure_metadata = if defined?(run_id) && defined?(pipeline_started_at)
          pipeline_metadata(
            context: context,
            run_id: run_id,
            duration_ms: duration_ms,
            degraded_steps: degraded_snapshot
          )
        end
        context.pipeline_metadata = failure_metadata if failure_metadata.is_a?(Hash)
        metadata = metadata.merge(
          trace: context.trace_entries,
          stage_metadata: context.stage_metadata,
          pipeline_snapshot: context.serializable_snapshot
        )
        metadata.merge!(failure_metadata) if failure_metadata.is_a?(Hash)
      end
      record_pipeline_event(stage: :pipeline, status: "failed", started_at: pipeline_started_at, message: e.message) if defined?(pipeline_started_at)
      flush_pending_events
      log_pipeline(:error, "pipeline_failed", run_id: run_id, error: e.message) if defined?(run_id)
      failure(e, metadata: metadata)
    end

    private

    attr_reader :login, :host_override, :overrides, :trigger_source, :skip_stages, :only_stages

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
        github_summary: summarize_github_payload(snapshot[:github_payload]),
        trigger: trigger_source
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

      persist_pipeline_event(profile: profile, stage: stage, status: status, started_at: started_at, message: message, trigger: trigger_source)
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
        message: message,
        trigger: trigger_source
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
            message: event[:message],
            trigger: event[:trigger] || trigger_source
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

    def persist_pipeline_event(profile:, stage:, status:, started_at:, message:, trigger:)
      duration_ms = if started_at && %w[completed failed].include?(status.to_s)
        ((Time.current - started_at) * 1000).to_i
      end

      ProfilePipelineEvent.create!(
        profile_id: profile.id,
        stage: stage.to_s,
        status: status.to_s,
        duration_ms: duration_ms,
        message: truncate_message(message),
        trigger: trigger,
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
        if context.avatar_local_path.present? || context.avatar_relative_path.present?
          {
            avatar_local_path: context.avatar_local_path,
            avatar_relative_path: context.avatar_relative_path
          }.compact
        end
      when :upload_github_avatar
        if context.avatar_public_url.present?
          {
            avatar_public_url: context.avatar_public_url,
            storage_key: context.avatar_upload_metadata&.[](:key)
          }.compact
        else
          result.metadata
        end
      when :store_github_profile
        profile = context.profile
        profile ? profile.attributes.slice(*snapshot_profile_keys) : nil
      when :record_avatar_asset
        result.metadata
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

    def skip_stage?(stage_id)
      symbol = stage_id.to_sym
      return true if only_stages.any? && !only_stages.include?(symbol)

      skip_stages.include?(symbol)
    end

    def notification_stage
      @notification_stage ||= self.class.stage_with_id(:notify_pipeline_outcome)
    end

    def perform_notification_stage(status:, context:, run_id:, pipeline_started_at:, degraded_steps:, error: nil)
      stage = notification_stage
      return unless stage

      context.degraded_steps = Array(degraded_steps).dup
      duration_ms = elapsed_ms(pipeline_started_at)
      metadata_snapshot = pipeline_metadata(
        context: context,
        run_id: run_id,
        duration_ms: duration_ms,
        degraded_steps: degraded_steps
      )
      context.pipeline_metadata = metadata_snapshot
      context.pipeline_outcome = {
        status: status.to_sym,
        run_id: run_id,
        duration_ms: duration_ms,
        degraded_steps: degraded_steps,
        metadata: metadata_snapshot,
        error: error,
        trigger: trigger_source
      }

      stage_started_at = Time.current
      record_stage_event(stage, status: "started", started_at: stage_started_at)
      result = execute_stage(stage, context)
      stage_duration_ms = elapsed_ms(stage_started_at)
      record_stage_snapshot(context, stage, result, stage_duration_ms)

      if result.failure?
        record_stage_event(stage, status: "failed", started_at: stage_started_at, message: result.error&.message)
      elsif result.degraded?
        record_stage_event(stage, status: "degraded", started_at: stage_started_at, message: degrade_message(result))
      else
        record_stage_event(stage, status: "completed", started_at: stage_started_at)
      end

      result
    rescue StandardError => e
      StructuredLogger.error(
        message: "pipeline_notification_stage_exception",
        service: self.class.name,
        login: login,
        error: e.message
      ) if defined?(StructuredLogger)
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

    def normalize_overrides(value)
      return {} if value.blank?

      case value
      when Hash
        value.deep_symbolize_keys
      else
        value.respond_to?(:to_h) ? value.to_h.deep_symbolize_keys : {}
      end
    rescue StandardError
      {}
    end

    def extract_trigger_source(overrides)
      candidate = overrides[:trigger_source]
      candidate = overrides[:trigger] if candidate.blank?
      candidate = candidate.call if candidate.respond_to?(:call)
      str = candidate.to_s.strip
      str.present? ? str : "unspecified"
    rescue StandardError
      "unspecified"
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
      payload_details[:trigger] ||= trigger_source
      StructuredLogger.public_send(
        level,
        { message: message, login: login }.merge(payload_details),
        component: "pipeline",
        event: "pipeline.#{message}",
        ops_details: { login: login, steps: self.class.steps, trigger: trigger_source }.merge(payload_details)
      )
    end
  end
end
