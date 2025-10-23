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
      context.trace(:pipeline, :started, login: login, host: context.host)

      STAGES.each do |stage|
        result = execute_stage(stage, context)
        return result if result.failure?
      end

      context.trace(:pipeline, :completed, card_id: context.result_value[:card_id])
      success(context.result_value, metadata: final_metadata(context))
    rescue StandardError => e
      metadata = { login: login, host: resolved_host }
      metadata[:trace] = context&.trace_entries if defined?(context) && context
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
