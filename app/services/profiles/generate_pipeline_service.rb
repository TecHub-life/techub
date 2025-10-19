module Profiles
  class GeneratePipelineService < ApplicationService
    VARIANTS = %w[og card simple banner].freeze

    def initialize(login:, host: nil, provider: nil, upload: nil, optimize: true, ai: true)
      @login = login.to_s.downcase
      resolved_host = host.presence || ENV["APP_HOST"].presence || (defined?(AppHost) ? AppHost.current : nil) || "http://127.0.0.1:3000"
      @host = resolved_host
      @provider = provider # nil respects default
      @upload = upload.nil? ? ENV["GENERATED_IMAGE_UPLOAD"].to_s.downcase.in?([ "1", "true", "yes" ]) : upload
      @optimize = optimize
      @ai = ai
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

      # 2) Optional: ingest submitted repos when present (flag-gated)
      if FeatureFlags.enabled?(:submission_manual_inputs)
        submitted_full_names = profile.profile_repositories.where(repository_type: "submitted").pluck(:full_name).compact
        if submitted_full_names.any?
          Profiles::IngestSubmittedRepositoriesService.call(profile: profile, repo_full_names: submitted_full_names)
        end
      end

      # 2b) Optional: scrape submitted URL for extra context (flag-gated)
      scraped = nil
      if FeatureFlags.enabled?(:submission_manual_inputs)
        if profile.respond_to?(:submitted_scrape_url) && profile.submitted_scrape_url.present?
          scraped_result = Profiles::RecordSubmittedScrapeService.call(profile: profile, url: profile.submitted_scrape_url)
          StructuredLogger.warn(message: "scrape_failed", login: login, error: scraped_result.error.message) if scraped_result.failure?
          scraped = scraped_result.value if scraped_result.success?
        end
      end

      images = nil
      ai_partial = false
      if ai
        # 3) Generate AI images (prompts + 4 variants)
        t0 = Time.current
        StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "ai_images") if defined?(StructuredLogger)
        images = Gemini::AvatarImageSuiteService.call(
          login: login,
          provider: provider,
          filename_suffix: provider,
          output_dir: Rails.root.join("public", "generated")
        )
        if images.failure?
          # Degrade gracefully: record event, mark partial, continue to screenshots + heuristic card
          ai_partial = true
          StructuredLogger.warn(message: "ai_images_failed", login: login, error: images.error.message) if defined?(StructuredLogger)
          record_event(profile, stage: "ai_images", status: "failed", duration_ms: ((Time.current - t0) * 1000).to_i, message: images.error.message)
        else
          StructuredLogger.info(message: "stage_completed", service: self.class.name, login: login, stage: "ai_images", duration_ms: ((Time.current - t0) * 1000).to_i) if defined?(StructuredLogger)
          record_event(profile, stage: "ai_images", status: "completed", duration_ms: ((Time.current - t0) * 1000).to_i)
        end

        # 3b) AI text + traits (structured)
        t1 = Time.current
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
        # Heuristic-only path
        StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "synth_heuristic") if defined?(StructuredLogger)
        synth = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
        return synth if synth.failure?
        StructuredLogger.info(message: "stage_completed", service: self.class.name, login: login, stage: "synth_heuristic", duration_ms: 0) if defined?(StructuredLogger)
      end

      # 5) Capture screenshots (OG/card/simple)
      StructuredLogger.info(message: "stage_started", service: self.class.name, login: login, stage: "screenshots") if defined?(StructuredLogger)
      captures = {}
      VARIANTS.each do |variant|
        shot = Screenshots::CaptureCardService.call(login: login, variant: variant, host: host)
        return shot if shot.failure?
        captures[variant] = shot.value

        # Persist/overwrite canonical asset row for lookups in UI and OG routes
        begin
          rec = ProfileAssets::RecordService.call(
            profile: profile,
            kind: variant,
            local_path: shot.value[:output_path],
            public_url: shot.value[:public_url],
            mime_type: shot.value[:mime_type],
            width: shot.value[:width],
            height: shot.value[:height],
            provider: "screenshot"
          )
          unless rec.success?
            StructuredLogger.warn(message: "record_asset_failed", login: login, variant: variant, error: rec.error&.message) if defined?(StructuredLogger)
          end
        rescue StandardError => e
          StructuredLogger.warn(message: "record_asset_exception", login: login, variant: variant, error: e.message) if defined?(StructuredLogger)
        end

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
      StructuredLogger.info(message: "stage_completed", service: self.class.name, login: login, stage: "screenshots") if defined?(StructuredLogger)
      record_event(profile, stage: "screenshots", status: "completed")

      # Card is expected to be persisted either by AI traits synthesis or heuristic fallback
      card_id = profile.profile_card&.id

      success(
        {
          login: login,
          images: images&.value,
          screenshots: captures,
          card_id: card_id,
          scraped: scraped
        },
        metadata: { login: login, provider: provider, upload: upload, optimize: optimize, partial: ai_partial }
      )
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :login, :host, :provider, :upload, :optimize, :ai

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
