module Profiles
  class GeneratePipelineService < ApplicationService
    VARIANTS = %w[og card simple banner].freeze

    def initialize(login:, host: nil, provider: nil, upload: nil, optimize: true, images: true, ai: nil)
      @login = login.to_s.downcase
      resolved_host = host.presence || ENV["APP_HOST"].presence || (defined?(AppHost) ? AppHost.current : nil) || "http://127.0.0.1:3000"
      @host = resolved_host
      @provider = provider # nil respects default
      @upload = upload.nil? ? ENV["GENERATED_IMAGE_UPLOAD"].to_s.downcase.in?([ "1", "true", "yes" ]) : upload
      @optimize = optimize
      # Back-compat: accept legacy ai: flag as alias for images
      @images = images.nil? ? ai : images
    end

    def call
      return failure(StandardError.new("login required")) if login.blank?

      pipeline_started = Time.current
      StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "sync") if defined?(StructuredLogger)
      # 1) Ensure profile + avatar exists
      sync = Profiles::SyncFromGithub.call(login: login)
      return sync if sync.failure?
      profile = sync.value
      StructuredLogger.info(message: "stage_completed", service: self.class.name, login: login, stage: "sync", duration_ms: ((Time.current - pipeline_started) * 1000).to_i) if defined?(StructuredLogger)
      record_event(profile, stage: "sync", status: "completed", duration_ms: ((Time.current - pipeline_started) * 1000).to_i)

      # 1.5) Eligibility gate (flagged)
      if FeatureFlags.enabled?(:require_profile_eligibility)
        elig = evaluate_eligibility(profile)
        unless elig[:eligible]
          return failure(StandardError.new("profile_not_eligible"), metadata: { eligibility: elig })
        end
      end

      # 2) Optional: ingest submitted repos when present (always on; noop if none)
      submitted_full_names = profile.profile_repositories.where(repository_type: "submitted").pluck(:full_name).compact
      if submitted_full_names.any?
        Profiles::IngestSubmittedRepositoriesService.call(profile: profile, repo_full_names: submitted_full_names)
      end

      # 2b) Optional: scrape submitted URL for extra context (always on; noop if none)
      scraped = nil
      if profile.respond_to?(:submitted_scrape_url) && profile.submitted_scrape_url.present?
        scraped_result = Profiles::RecordSubmittedScrapeService.call(profile: profile, url: profile.submitted_scrape_url)
        StructuredLogger.warn(message: "scrape_failed", login: login, error: scraped_result.error.message) if scraped_result.failure?
        scraped = scraped_result.value if scraped_result.success?
      end

      image_suite = nil
      ai_partial = false
      # 3) AI Images: controlled by feature flag and the `images` parameter
      if images
        t0 = Time.current
        StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "ai_images") if defined?(StructuredLogger)
        if FeatureFlags.enabled?(:ai_images)
          # Allow images provider override independent from global provider
          images_provider = provider.presence || ENV["GEMINI_IMAGES_PROVIDER"].to_s.presence
          image_suite = Gemini::AvatarImageSuiteService.call(
            login: login,
            provider: images_provider,
            filename_suffix: images_provider,
            output_dir: Rails.root.join("public", "generated")
          )
          if image_suite.failure?
            ai_partial = true
            StructuredLogger.warn(message: "ai_images_failed", login: login, error: image_suite.error.message) if defined?(StructuredLogger)
            record_event(profile, stage: "ai_images", status: "failed", duration_ms: ((Time.current - t0) * 1000).to_i, message: image_suite.error.message)
          else
            StructuredLogger.info(message: "stage_completed", service: self.class.name, login: login, stage: "ai_images", duration_ms: ((Time.current - t0) * 1000).to_i) if defined?(StructuredLogger)
            record_event(profile, stage: "ai_images", status: "completed", duration_ms: ((Time.current - t0) * 1000).to_i)
          end
        else
          # Images disabled by policy — do NOT mark partial; this is expected
          StructuredLogger.info(message: "ai_images_skipped_policy", login: login) if defined?(StructuredLogger)
        end
      else
        # Images explicitly disabled for this run — do NOT mark partial
        StructuredLogger.info(message: "ai_images_disabled_run", login: login) if defined?(StructuredLogger)
      end

      # 3b) AI text + traits: gated (defaults ON); fallback to heuristic if taped off or failed
      t1 = Time.current
      if FeatureFlags.enabled?(:ai_text)
        StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "ai_traits") if defined?(StructuredLogger)
        # Force AI Studio for text traits (Vertex flaky with prose-only responses)
        ai_traits = Profiles::SynthesizeAiProfileService.call(profile: profile, provider: "ai_studio")
        if ai_traits.failure?
          StructuredLogger.warn(message: "ai_traits_failed", login: login, error: ai_traits.error.message) if defined?(StructuredLogger)
          record_event(profile, stage: "ai_traits", status: "failed", duration_ms: ((Time.current - t1) * 1000).to_i, message: ai_traits.error.message)
          ai_partial = true
          # Fallback to heuristic synthesis
          StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "synth_heuristic") if defined?(StructuredLogger)
          synth = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
          return synth if synth.failure?
          StructuredLogger.info(message: "stage_completed", service: self.class.name, login: login, stage: "synth_heuristic", duration_ms: 0) if defined?(StructuredLogger)
          record_event(profile, stage: "synth_heuristic", status: "completed", duration_ms: 0)
        else
          # Propagate partial flag when AI succeeded via fallback inside the service
          begin
            meta = ai_traits.metadata if ai_traits.respond_to?(:metadata)
            ai_partial ||= !!(meta && meta[:partial])
          rescue StandardError
          end
          StructuredLogger.info(message: "stage_completed", service: self.class.name, login: login, stage: "ai_traits", duration_ms: ((Time.current - t1) * 1000).to_i) if defined?(StructuredLogger)
          record_event(profile, stage: "ai_traits", status: "completed", duration_ms: ((Time.current - t1) * 1000).to_i)
        end
      else
        # Text AI disabled by policy — use heuristic synthesis; do NOT mark partial
        StructuredLogger.info(message: "ai_traits_skipped_policy", login: login) if defined?(StructuredLogger)
        StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "synth_heuristic") if defined?(StructuredLogger)
        synth = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
        return synth if synth.failure?
        StructuredLogger.info(message: "stage_completed", service: self.class.name, login: login, stage: "synth_heuristic", duration_ms: 0) if defined?(StructuredLogger)
        record_event(profile, stage: "synth_heuristic", status: "completed", duration_ms: 0)
      end

      # 5) Capture screenshots (enqueue all core variants asynchronously)
      StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "screenshots") if defined?(StructuredLogger)
      if Rails.env.production? && host.to_s.include?("127.0.0.1")
        StructuredLogger.warn(message: "app_host_fallback_local", service: self.class.name, login: login, host: host)
      end
      VARIANTS.each do |variant|
        Screenshots::CaptureCardJob.perform_later(login: login, variant: variant, host: host)
      end
      StructuredLogger.info(message: "stage_enqueued", service: self.class.name, login: login, stage: "screenshots", variants: VARIANTS) if defined?(StructuredLogger)
      record_event(profile, stage: "screenshots", status: "enqueued")

      # 6) Capture social-target screenshots (no resizing path)
      begin
        StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "social_assets") if defined?(StructuredLogger)
        Screenshots::CaptureCardService::SOCIAL_VARIANTS.each do |kind|
          Screenshots::CaptureCardJob.perform_later(login: login, variant: kind, host: host)
        end
        StructuredLogger.info(message: "stage_enqueued", service: self.class.name, login: login, stage: "social_assets") if defined?(StructuredLogger)
      rescue StandardError => e
        StructuredLogger.warn(message: "social_assets_exception", login: login, error: e.message) if defined?(StructuredLogger)
      end

      # Card is expected to be persisted either by AI traits synthesis or heuristic fallback
      card_id = profile.profile_card&.id

      success(
        {
          login: login,
          images: image_suite&.value,
          screenshots: nil,
          card_id: card_id,
          scraped: scraped
        },
        metadata: { login: login, provider: provider, upload: upload, optimize: optimize, partial: ai_partial }
      )
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :login, :host, :provider, :upload, :optimize, :images

    def record_event(profile, stage:, status:, duration_ms: nil, message: nil)
      ProfilePipelineEvent.create!(profile_id: profile.id, stage: stage, status: status, duration_ms: duration_ms, message: message, created_at: Time.current)
    rescue StandardError => e
      StructuredLogger.warn(message: "pipeline_event_record_failed", login: profile.login, stage: stage, status: status, error: e.message) if defined?(StructuredLogger)
    end

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
