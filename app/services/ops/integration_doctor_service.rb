require "json"
require "securerandom"
require "set"

module Ops
  class IntegrationDoctorService < ApplicationService
    DEFAULT_PROVIDERS = %w[ai_studio vertex].freeze
    DEFAULT_SCOPES = %w[gemini axiom github spaces].freeze
    DEFAULT_SAMPLE_IMAGE = Rails.root.join("public", "icon.png").freeze

    def initialize(
      providers: DEFAULT_PROVIDERS,
      scopes: DEFAULT_SCOPES,
      github_login: ENV["OPS_DOCTOR_GITHUB_LOGIN"].presence || "loftwah",
      sample_image_path: DEFAULT_SAMPLE_IMAGE,
      progress_io: $stdout
    )
      @providers = normalize_list(providers, DEFAULT_PROVIDERS)
      @scopes = normalize_list(scopes, DEFAULT_SCOPES)
      @scope_set = @scopes.to_set
      @github_login = github_login.to_s.strip.presence || "loftwah"
      @sample_image_path = Pathname.new(sample_image_path)
      @output_dir = Rails.root.join("tmp", "integration_doctor")
      @progress_io = progress_io if progress_io.respond_to?(:puts)
    end

    def call
      report = {
        started_at: Time.current,
        scopes: scopes,
        providers: providers,
        github_login: github_login,
        checks: []
      }

      checks = []
      if scope_enabled?(:gemini)
        providers.each do |provider|
          checks.concat(run_gemini_checks(provider))
        end
      end
      checks << check_axiom if scope_enabled?(:axiom)
      checks.concat(run_github_checks) if scope_enabled?(:github)
      checks << check_spaces if scope_enabled?(:spaces)

      report[:checks] = checks
      report[:finished_at] = Time.current
      report[:duration_ms] = elapsed_ms(report[:started_at], report[:finished_at])
      report[:ok] = checks.all? { |c| c[:status] == "ok" }

      report[:ok] ? success(report, metadata: report) : failure(StandardError.new("integration_doctor_failed"), metadata: report)
    end

    private

    attr_reader :providers, :scopes, :scope_set, :github_login, :sample_image_path, :output_dir, :progress_io

    # ---- Scope helpers ----------------------------------------------------

    def scope_enabled?(name)
      scope_set.include?(name.to_s)
    end

    def normalize_list(value, fallback)
      list = Array(value).flat_map { |v| v.to_s.split(",") }.map { |item| item.to_s.strip.downcase }.reject(&:blank?).uniq
      list = fallback if list.empty? || list.include?("all")
      list
    end

    def ensure_sample_image!
      return if sample_image_path.exist?
      raise StandardError, "Sample image not found at #{sample_image_path}"
    end

    # ---- Gemini checks ----------------------------------------------------

    def run_gemini_checks(provider)
      ensure_sample_image!
      cleanup_old_artifacts(provider)
      [
        check_gemini_text(provider),
        check_gemini_structured_output(provider),
        check_gemini_image_description(provider),
        check_gemini_text_to_image(provider),
        check_gemini_image_to_image(provider)
      ]
    rescue StandardError => e
      [ fail_check("gemini.#{provider}.setup", e) ]
    end

    def check_gemini_text(provider)
      wrap_service_check("gemini.#{provider}.text_generation", value_formatter: ->(value) { truncate(value.to_s.strip) }) do
        Gemini::TextGenerationService.call(
          prompt: "Reply with 'TecHub ready.' exactly.",
          temperature: 0.1,
          max_output_tokens: 32,
          provider: provider
        )
      end
    end

    def check_gemini_structured_output(provider)
      schema = {
        type: "object",
        properties: {
          colors: {
            type: "array",
            items: { type: "string" },
            minItems: 2,
            maxItems: 2
          }
        },
        required: %w[colors]
      }
      wrap_service_check(
        "gemini.#{provider}.structured_output",
        value_formatter: ->(value) { value }
      ) do
        Gemini::StructuredOutputService.call(
          prompt: { question: "List 2 neon colors." }.to_json,
          response_schema: schema,
          temperature: 0.2,
          provider: provider
        )
      end
    end

    def check_gemini_image_description(provider)
      wrap_service_check(
        "gemini.#{provider}.image_description",
        value_formatter: ->(value) { truncate(value.to_s) }
      ) do
        Gemini::ImageDescriptionService.call(
          image_path: sample_image_path,
          provider: provider,
          force: true,
          max_output_tokens: 200
        )
      end
    end

    def check_gemini_text_to_image(provider)
      path = temp_output_path("text-to-image", provider)
      wrap_service_check(
        "gemini.#{provider}.text_to_image",
        value_formatter: ->(value) { summarize_image_value(value) }
      ) do
        Gemini::ImageGenerationService.call(
          prompt: "Render a minimal monochrome TecHub badge icon.",
          aspect_ratio: "1:1",
          output_path: path,
          provider: provider,
          force: true
        )
      end
    end

    def check_gemini_image_to_image(provider)
      path = temp_output_path("image-to-image", provider)
      wrap_service_check(
        "gemini.#{provider}.image_to_image",
        value_formatter: ->(value) { summarize_image_value(value) }
      ) do
        Gemini::ImageGenerationService.call(
          prompt: "Apply a grayscale filter to the supplied icon.",
          aspect_ratio: "1:1",
          output_path: path,
          provider: provider,
          reference_image_path: sample_image_path,
          force: true
        )
      end
    end

    def summarize_image_value(value)
      return {} unless value.is_a?(Hash)
      {
        mime_type: value[:mime_type],
        byte_size: value[:bytes]&.bytesize,
        output_path: value[:output_path]
      }.compact
    end

    # ---- Axiom ------------------------------------------------------------

    def check_axiom
      wrap_service_check("axiom.ingest") do
        dataset = AppConfig.axiom[:dataset]
        event = {
          ts: Time.now.utc.iso8601,
          level: "INFO",
          message: "integration_doctor_probe",
          env: Rails.env,
          app: AppConfig.app[:name]
        }
        Axiom::IngestService.call(dataset: dataset, events: [ event ])
      end
    end

    # ---- GitHub -----------------------------------------------------------

    def run_github_checks
      [
        check_github_configuration,
        check_github_app_client,
        check_github_profile_fetch
      ]
    end

    def check_github_configuration
      announce_start("github.configuration")
      missing = []
      begin
        Github::Configuration.app_id
      rescue KeyError
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
      begin
        Github::Configuration.private_key
      rescue StandardError
        missing << :private_key
      end
      missing << :installation_id if Github::Configuration.installation_id.to_i <= 0
      result = if missing.empty?
        ok("github.configuration")
      else
        fail_check("github.configuration", "missing GitHub config", missing: missing)
      end
      announce_result(result)
      result
    end

    def check_github_app_client
      wrap_service_check("github.app_client") do
        Github::AppClientService.call
      end
    end

    def check_github_profile_fetch
      wrap_service_check(
        "github.profile_summary",
        value_formatter: ->(value) { value.is_a?(Hash) ? value.slice(:login, :followers, :public_repos) : value }
      ) do
        GithubProfile::ProfileSummaryService.call(login: github_login)
      end
    end

    # ---- DigitalOcean Spaces / Active Storage ----------------------------

    def check_spaces
      unless Storage::ServiceProfile.remote_service?
        return ok("spaces.upload", skipped: true, reason: "active_storage_disk_service")
      end

      Tempfile.create([ "integration-doctor", ".txt" ]) do |file|
        file.write("ops-doctor #{Time.now.utc.iso8601}")
        file.flush
        started = monotonic_time
        result = Storage::ActiveStorageUploadService.call(
          path: file.path,
          content_type: "text/plain",
          filename: "ops-integration-doctor.txt"
        )
        if result.success?
          purge_blob_async(result.value[:key])
        end
        wrap_service_result("spaces.upload", result, started_at: started)
      end
    end

    def purge_blob_async(key)
      blob = ActiveStorage::Blob.find_by(key: key)
      blob&.purge_later
    rescue StandardError
      # best effort
    end

    # ---- Helpers ----------------------------------------------------------

    def wrap_service_check(name, value_formatter: nil)
      announce_start(name)
      started = monotonic_time
      result = yield
      wrapped = wrap_service_result(name, result, started_at: started, value_formatter: value_formatter)
      announce_result(wrapped)
      wrapped
    rescue StandardError => e
      failure = fail_check(name, e, duration_ms: elapsed_ms(started))
      announce_result(failure)
      failure
    end

    def wrap_service_result(name, result, started_at: Process.clock_gettime(Process::CLOCK_MONOTONIC), value_formatter: nil)
      metadata = (result.metadata || {}).dup
      metadata[:duration_ms] = elapsed_ms(started_at)
      if result.success?
        if value_formatter
          snapshot = value_formatter.call(result.value)
          metadata[:value] = snapshot if snapshot.present?
        end
        ok(name, metadata)
      else
        metadata[:error_class] = result.error.class.name if result.error
        fail_check(name, result.error || "unknown_error", metadata)
      end
    end

    def announce_start(name)
      return unless progress_io
      progress_io.puts("[ops:doctor] → #{name}")
      progress_io.flush
    end

    def announce_result(result)
      return unless progress_io
      status = result[:status].to_s.upcase
      progress_io.puts("[ops:doctor] ← #{result[:name]} #{status}")
      progress_io.flush
    end

    def truncate(text, limit = 140)
      return nil if text.blank?
      text.length > limit ? "#{text[0, limit]}…" : text
    end

    def ok(name, metadata = {})
      { name: name, status: "ok", metadata: metadata.compact }
    end

    def warn_check(name, error, metadata = {})
      { name: name, status: "warn", error: error.to_s, metadata: metadata }
    end

    def fail_check(name, error, metadata = {})
      { name: name, status: "fail", error: error.to_s, metadata: metadata }
    end

    def temp_output_path(kind, provider)
      FileUtils.mkdir_p(output_dir)
      filename = "#{kind}-#{provider}-#{SecureRandom.hex(4)}.png"
      output_dir.join(filename)
    end

    def cleanup_old_artifacts(provider)
      return unless output_dir.exist?
      Dir.glob(output_dir.join("*-#{provider}-*.png")).each do |path|
        FileUtils.rm_f(path)
      end
    rescue StandardError
      # best effort
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms(start_clock, finish = nil)
      if start_clock.is_a?(Time)
        finish ||= Time.current
        return ((finish - start_clock) * 1000).to_i
      end
      finish ||= monotonic_time
      ((finish - start_clock) * 1000).to_i
    end
  end
end
