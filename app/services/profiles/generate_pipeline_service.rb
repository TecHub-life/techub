module Profiles
  class GeneratePipelineService < ApplicationService
    VARIANTS = %w[og card simple].freeze

    def initialize(login:, host: nil, provider: nil, upload: nil, optimize: true, ai: true)
      @login = login.to_s.downcase
      @host = host.presence || ENV["APP_HOST"].presence || "http://127.0.0.1:3000"
      @provider = provider # nil respects default
      @upload = upload.nil? ? ENV["GENERATED_IMAGE_UPLOAD"].to_s.downcase.in?([ "1", "true", "yes" ]) : upload
      @optimize = optimize
      @ai = ai
    end

    def call
      return failure(StandardError.new("login required")) if login.blank?

      # 1) Ensure profile + avatar exists
      sync = Profiles::SyncFromGithub.call(login: login)
      return sync if sync.failure?
      profile = sync.value

      # 1.5) Eligibility gate (flagged)
      if FeatureFlags.enabled?(:require_profile_eligibility)
        elig = evaluate_eligibility(profile)
        unless elig[:eligible]
          return failure(StandardError.new("profile_not_eligible"), metadata: { eligibility: elig })
        end
      end

      # 2) Optional: ingest submitted repos + scrape submitted URL (flagged)
      if FeatureFlags.enabled?(:submission_manual_inputs)
        submitted_full_names = profile.profile_repositories.where(repository_type: "submitted").pluck(:full_name).compact
        if submitted_full_names.any?
          Profiles::IngestSubmittedRepositoriesService.call(profile: profile, repo_full_names: submitted_full_names)
        end
      end

      # 2b) Optional: scrape submitted URL for extra context (flagged)
      scraped = nil
      if FeatureFlags.enabled?(:submission_manual_inputs) && profile.respond_to?(:submitted_scrape_url) && profile.submitted_scrape_url.present?
        scraped_result = Profiles::RecordSubmittedScrapeService.call(profile: profile, url: profile.submitted_scrape_url)
        StructuredLogger.warn(message: "scrape_failed", login: login, error: scraped_result.error.message) if scraped_result.failure?
        scraped = scraped_result.value if scraped_result.success?
      end

      images = nil
      if ai
        # 3) Generate AI images (prompts + 4 variants)
        images = Gemini::AvatarImageSuiteService.call(
          login: login,
          provider: provider,
          filename_suffix: provider,
          output_dir: Rails.root.join("public", "generated")
        )
        return images if images.failure?
      end

      # 4) Synthesize card attributes and persist
      synth = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
      return synth if synth.failure?

      # 5) Capture screenshots (OG/card/simple)
      captures = {}
      VARIANTS.each do |variant|
        shot = Screenshots::CaptureCardService.call(login: login, variant: variant, host: host)
        return shot if shot.failure?
        captures[variant] = shot.value

        # Optional: move heavy optimization to background for larger assets
        if optimize
          begin
            file_size = File.size(shot.value[:output_path]) rescue 0
            threshold = (ENV["IMAGE_OPT_BG_THRESHOLD"] || 300_000).to_i
            fmt = nil # keep current format

            # Enqueue background optimization when file is larger than threshold
            if file_size >= threshold
              Images::OptimizeJob.perform_later(
                path: shot.value[:output_path],
                login: login,
                kind: variant,
                format: fmt,
                quality: nil,
                min_bytes_for_bg: threshold,
                upload: upload
              )
            else
              # For small files, do a quick inline pass (best-effort)
              Images::OptimizeService.call(path: shot.value[:output_path], output_path: shot.value[:output_path], format: fmt)
            end
          rescue StandardError => e
            StructuredLogger.warn(message: "optimize_enqueue_failed", login: login, variant: variant, error: e.message)
          end
        end
      end

      success(
        {
          login: login,
          images: images&.value,
          screenshots: captures,
          card_id: synth.value.id,
          scraped: scraped
        },
        metadata: { login: login, provider: provider, upload: upload, optimize: optimize }
      )
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :login, :host, :provider, :upload, :optimize, :ai

    def evaluate_eligibility(profile)
      repositories = profile.profile_repositories.map do |r|
        { private: false, archived: false, pushed_at: r.github_updated_at, owner_login: (r.full_name&.split("/")&.first || profile.login) }
      end
      recent_activity = {
        total_events: profile.profile_activity&.total_events.to_i
      }
      pinned = profile.profile_repositories.where(repository_type: "pinned").map { |r| { name: r.name } }
      readme = profile.profile_readme&.content
      orgs = profile.profile_organizations.map { |o| { login: o.login } }

      payload = {
        login: profile.login,
        followers: profile.followers,
        following: profile.following,
        created_at: profile.github_created_at
      }

      result = Eligibility::GithubProfileScoreService.call(
        profile: payload,
        repositories: repositories,
        recent_activity: recent_activity,
        pinned_repositories: pinned,
        profile_readme: readme,
        organizations: orgs
      )
      result.value
    end
  end
end
