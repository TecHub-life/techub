module Profiles
  class PipelineDoctorService < ApplicationService
    DEFAULT_VARIANTS = Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS

    def initialize(login:, host: nil, email: nil, variants: DEFAULT_VARIANTS)
      @login = login.to_s.downcase
      @host = host
      @email = email.to_s.strip.presence
      @variants = Array(variants).map(&:to_s)
    end

    def call
      raise ArgumentError, "login required" if login.blank?

      report = {
        login: login,
        started_at: Time.current,
        host: resolved_host,
        checks: [],
        ok: true
      }

      checks = []

      # 1) GitHub configuration
      checks << check_github_configuration

      # 2) GitHub App client (installation id + token)
      checks << check_github_app_client

      # 3) Fetch GitHub summary for login
      checks << check_github_profile_fetch

      # 4) Avatar download (does not persist)
      checks << check_avatar_download

      # 5) Persist profile (DB write)
      checks << check_persist_profile

      # 6) AI traits generation (or heuristic fallback), respecting feature flags
      checks << check_ai_profile

      # 7) Screenshots via Puppeteer for requested variants
      checks << check_screenshots

      # Aggregate
      report[:checks] = checks
      report[:ok] = checks.all? { |c| c[:status] == "ok" }
      report[:finished_at] = Time.current

      if email.present? && defined?(Notifications::OpsAlertService)
        begin
          if report[:ok]
            Notifications::OpsAlertService.call(profile: Profile.for_login(login).first, job: self.class.name, error_message: nil, metadata: report, duration_ms: duration_ms(report))
          else
            Notifications::OpsAlertService.call(profile: Profile.for_login(login).first, job: self.class.name, error_message: "pipeline_doctor_failed", metadata: report, duration_ms: duration_ms(report))
          end
        rescue StandardError
        end
      end

      report[:ok] ? success(report) : failure(StandardError.new("pipeline_doctor_failed"), metadata: report)
    end

    private

    attr_reader :login, :host, :email, :variants

    def duration_ms(report)
      ((report[:finished_at] - report[:started_at]) * 1000).to_i rescue nil
    end

    def resolved_host
      host.presence || Profiles::GeneratePipelineService::FALLBACK_HOSTS.fetch(Rails.env, "http://127.0.0.1:3000")
    end

    def ok(name, meta = {})
      { name: name, status: "ok", metadata: meta }
    end

    def warn_check(name, error)
      { name: name, status: "warn", error: error.to_s }
    end

    def fail_check(name, error, meta = {})
      { name: name, status: "fail", error: error.to_s, metadata: meta }
    end

    def check_github_configuration
      missing = []
      begin
        Github::Configuration.app_id
      rescue KeyError => e
        missing << :app_id
      end
      begin
        Github::Configuration.client_id
      rescue KeyError
        missing << :client_id
      end
      begin
        Github::Configuration.client_secret
      rescue KeyError
        missing << :client_secret
      end
      # private key is required for app auth
      begin
        Github::Configuration.private_key
      rescue StandardError
        missing << :private_key
      end
      if Github::Configuration.installation_id.to_i <= 0
        missing << :installation_id
      end
      return ok("github_configuration") if missing.empty?
      fail_check("github_configuration", "Missing GitHub config", missing: missing)
    end

    def check_github_app_client
      result = Github::AppClientService.call
      return ok("github_app_client", expires_at: result.metadata&.[](:expires_at)) if result.success?
      fail_check("github_app_client", result.error || "unknown")
    end

    def check_github_profile_fetch
      result = Github::ProfileSummaryService.call(login: login)
      return ok("github_profile_fetch", have: (result.value || {}).keys) if result.success?
      fail_check("github_profile_fetch", result.error || "unknown")
    end

    def check_avatar_download
      context = Profiles::Pipeline::Context.new(login: login, host: resolved_host)
      result = Profiles::Pipeline::Stages::DownloadAvatar.call(context: context)
      return ok("avatar_download", local_path: context.avatar_local_path) if result.success?
      warn_check("avatar_download", result.error || "unknown")
    end

    def check_persist_profile
      context = Profiles::Pipeline::Context.new(login: login, host: resolved_host)
      fetch = Profiles::Pipeline::Stages::FetchGithubProfile.call(context: context)
      return fail_check("persist_profile", fetch.error || "fetch_failed") if fetch.failure?

      persist = Profiles::Pipeline::Stages::PersistGithubProfile.call(context: context)
      return ok("persist_profile", profile_id: context.profile&.id) if persist.success?
      fail_check("persist_profile", persist.error || "unknown")
    end

    def check_ai_profile
      profile = Profile.for_login(login).first
      return fail_check("ai_profile", "profile_missing") unless profile

      if FeatureFlags.enabled?(:ai_text)
        result = Profiles::SynthesizeAiProfileService.call(profile: profile, provider: "ai_studio")
        return ok("ai_profile", provider: "ai_studio", card_id: result.value&.id) if result.success?
        warn_check("ai_profile", result.error || "ai_traits_failed")
      else
        result = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
        return ok("ai_profile", provider: "heuristic", card_id: profile.profile_card&.id) if result.success?
        fail_check("ai_profile", result.error || "card_synthesis_failed")
      end
    end

    def check_screenshots
      profile = Profile.for_login(login).first
      return fail_check("screenshots", "profile_missing") unless profile

      missing = []
      failures = {}
      captures = {}
      variants.each do |variant|
        res = Screenshots::CaptureCardService.call(login: profile.login, variant: variant, host: resolved_host)
        if res.success?
          captures[variant] = res.value
        else
          failures[variant] = res.error&.message || "failed"
        end
      end

      if failures.empty?
        ok("screenshots", variants: variants, captures: captures.transform_values { |v| v.slice(:output_path, :public_url, :width, :height) })
      else
        fail_check("screenshots", "some_variants_failed", failures: failures, ok: captures.keys)
      end
    end
  end
end
