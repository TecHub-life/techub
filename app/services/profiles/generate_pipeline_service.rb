module Profiles
  class GeneratePipelineService < ApplicationService
    Stage = Struct.new(:id, :label, :service, :options, keyword_init: true)

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
        options: {}
      ),
      Stage.new(
        id: :download_github_avatar,
        label: "Download GitHub avatar",
        service: Pipeline::Stages::DownloadAvatar,
        options: {}
      ),
      Stage.new(
        id: :store_github_profile,
        label: "Store GitHub data",
        service: Pipeline::Stages::PersistGithubProfile,
        options: {}
      ),
      Stage.new(
        id: :evaluate_eligibility,
        label: "Evaluate eligibility",
        service: Pipeline::Stages::EvaluateEligibility,
        options: {}
      ),
      Stage.new(
        id: :ingest_submitted_repositories,
        label: "Ingest submitted repositories",
        service: Pipeline::Stages::IngestSubmittedRepositories,
        options: {}
      ),
      Stage.new(
        id: :record_submitted_scrape,
        label: "Record submitted scrape",
        service: Pipeline::Stages::RecordSubmittedScrape,
        options: {}
      ),
      Stage.new(
        id: :generate_ai_profile,
        label: "Generate AI profile",
        service: Pipeline::Stages::GenerateAiProfile,
        options: {}
      ),
      Stage.new(
        id: :capture_card_screenshots,
        label: "Capture card screenshots",
        service: Pipeline::Stages::CaptureScreenshots,
        options: { variants: SCREENSHOT_VARIANTS }
      ),
      Stage.new(
        id: :optimize_card_images,
        label: "Optimize card images",
        service: Pipeline::Stages::OptimizeScreenshots,
        options: {}
      )
    ].freeze

    def initialize(login:, host: nil)
      @login = login.to_s.downcase
      @host_override = host
    end

    def call
      return failure(StandardError.new("login required"), metadata: { stage: :pipeline }) if login.blank?

      context = Pipeline::Context.new(login: login, host: resolved_host)
      @last_known_profile = Profile.for_login(login).first
      context.trace(:pipeline, :started, login: login, host: context.host)
      @pending_pipeline_events = []
      pipeline_started_at = Time.current
      record_pipeline_event(stage: :pipeline, status: "started", started_at: pipeline_started_at)

      STAGES.each do |stage|
        stage_started_at = Time.current
        record_stage_event(stage, status: "started", started_at: stage_started_at)

        result = execute_stage(stage, context)
        if result.failure?
          record_stage_event(stage, status: "failed", started_at: stage_started_at, message: result.error&.message)
          record_pipeline_event(stage: :pipeline, status: "failed", started_at: pipeline_started_at, message: result.error&.message)
          return result
        end

        refresh_event_profile(context)
        record_stage_event(stage, status: "completed", started_at: stage_started_at)
      end

      context.trace(:pipeline, :completed, card_id: context.result_value[:card_id])
      record_pipeline_event(stage: :pipeline, status: "completed", started_at: pipeline_started_at)
      flush_pending_events
      success(context.result_value, metadata: final_metadata(context))
    rescue StandardError => e
      metadata = { login: login, host: resolved_host }
      metadata[:trace] = context&.trace_entries if defined?(context) && context
      record_pipeline_event(stage: :pipeline, status: "failed", started_at: pipeline_started_at, message: e.message) if defined?(pipeline_started_at)
      flush_pending_events
      failure(e, metadata: metadata)
    end

    private

    attr_reader :login, :host_override

    def execute_stage(stage, context)
      result = stage.service.call(context: context, **stage.options)
      return failure(result.error, metadata: failure_metadata(context, stage, result)) if result.failure?

      context.trace(stage.id, :succeeded, label: stage.label)
      ServiceResult.success(true)
    rescue StandardError => e
      context.trace(stage.id, :exception, error: e.message)
      failure(e, metadata: failure_metadata(context, stage))
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
        trace: context.trace_entries
      }
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

    def resolved_host
      return @resolved_host if defined?(@resolved_host)

      explicit = host_override.presence || ENV["APP_HOST"].presence
      @resolved_host = if explicit.present?
        explicit
      else
        FALLBACK_HOSTS.fetch(Rails.env, FALLBACK_HOSTS["production"])
      end
    end
  end
end
