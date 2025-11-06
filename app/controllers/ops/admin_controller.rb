module Ops
  class AdminController < BaseController
    ALLOWED_LOG_LEVELS = %w[debug info warn error fatal].freeze

    def index
      # Reflect whether /ops/jobs is actually mounted in this env
      @engine_present = begin
        defined?(MissionControl::Jobs::Engine) &&
          Rails.application.routes.routes.any? { |r| r.path.spec.to_s.start_with?("/ops/jobs") }
      rescue StandardError
        false
      end
      @adapter = ActiveJob::Base.queue_adapter

      @stats = {
        queued: nil,
        ready: nil,
        running: nil,
        failed: nil,
        finished_last_hour: nil
      }

      # High-level profile status counts for quick health overview
      begin
        raw = Profile.group(:last_pipeline_status).count
        @status_counts = {
          success: raw["success"].to_i,
          partial_success: raw["partial_success"].to_i,
          failure: raw["failure"].to_i,
          queued: raw["queued"].to_i,
          unknown: (raw[nil] || 0).to_i
        }
      rescue StandardError
        @status_counts = { success: 0, partial_success: 0, failure: 0, queued: 0, unknown: 0 }
      end

      if defined?(SolidQueue)
        begin
          @stats[:queued] = (SolidQueue::Job.where(finished_at: nil).count rescue nil)
          @stats[:ready] = (SolidQueue::ReadyExecution.count rescue nil)
          @stats[:running] = (SolidQueue::ClaimedExecution.count rescue nil)
          @stats[:failed] = (SolidQueue::FailedExecution.count rescue nil)
          @stats[:finished_last_hour] = (SolidQueue::Job.where.not(finished_at: nil).where("finished_at > ?", 1.hour.ago).count rescue nil)
        rescue StandardError => e
          @error = e.message
        end
      end

      @dev_log_tail = tail_log("log/development.log", 200) if Rails.env.development?

      # Failed profiles (last pipeline failed). Keep list small for UI.
      begin
        @failed_profiles = Profile.where(last_pipeline_status: "failure").order(updated_at: :desc).limit(50)
        # Preload recent pipeline events for failed profiles to show failure details (esp. screenshots)
        if @failed_profiles.any?
          events = ProfilePipelineEvent
            .where(profile_id: @failed_profiles.map(&:id))
            .order(created_at: :desc)
            .limit(500)
          @failed_events_by_profile_id = events.group_by(&:profile_id)
        else
          @failed_events_by_profile_id = {}
        end
      rescue StandardError
        @failed_profiles = []
        @failed_events_by_profile_id = {}
      end

      # Recent successful profiles (last pipeline success or partial_success)
      begin
        @recent_success_profiles = Profile
          .where(last_pipeline_status: [ "success", "partial_success" ])
          .order(updated_at: :desc)
          .limit(50)
      rescue StandardError
        @recent_success_profiles = []
      end

      # Profiles that claim success but are missing expected associated data
      begin
        candidates = Profile.where(last_pipeline_status: "success").includes(:profile_card, :profile_languages, :profile_repositories)
        @data_issues_profiles = candidates.select do |p|
          p.profile_card.nil? || !p.profile_languages.exists? || !p.profile_repositories.exists?
        end.first(50)
      rescue StandardError
        @data_issues_profiles = []
      end

      # GitHub App installation diagnostics for ops panel (read-only)
      @configured_installation_id = Github::Configuration.installation_id

      # Access settings
      @open_access = AppSetting.get_bool(:open_access, default: false)
      @allowed_logins = Array(AppSetting.get_json(:allowed_logins, default: Access::Policy::DEFAULT_ALLOWED)).map { |l| l.to_s.downcase }.uniq.join(", ")
      @invite_cap_limit = Access::InviteCodes.limit
      @invite_cap_used  = Access::InviteCodes.used_count
      @invite_codes_override = Array(AppSetting.get_json(:sign_up_codes_override, default: [])).join(", ")

      # AI capabilities state (for visibility)
      begin
        Gemini::Configuration.validate!
        model_ok = true
      rescue StandardError
        model_ok = false
      end
      @ai_caps = {
        image_generation: FeatureFlags.enabled?(:ai_images),
        image_descriptions: FeatureFlags.enabled?(:ai_image_descriptions),
        text_output: (FeatureFlags.enabled?(:ai_text) && model_ok),
        structured_output: (FeatureFlags.enabled?(:ai_structured_output) && model_ok),
        provider: (Gemini::Configuration.provider rescue nil),
        model: (Gemini::Configuration.model rescue nil)
      }

      # Axiom links (datasets + traces)
      begin
        axiom_cfg = AppConfig.axiom
        forwarding = AppConfig.axiom_forwarding
        queue_stats = StructuredLogger.forwarding_stats

        traces_url = if axiom_cfg[:token].present? && axiom_cfg[:otel_endpoint].present?
          axiom_cfg[:traces_url]
        end

        @axiom = {
          dataset_url: axiom_cfg[:dataset_url],
          metrics_dataset_url: axiom_cfg[:metrics_dataset_url],
          traces_url: traces_url
        }

        @axiom_status = {
          env: AppConfig.environment,
          forwarding_allowed: forwarding[:allowed],
          forwarding_reason: forwarding[:reason],
          token_present: forwarding[:token_present],
          dataset_present: forwarding[:dataset_present],
          metrics_dataset_present: axiom_cfg[:metrics_dataset].present?,
          auto_forward: forwarding[:auto_forward],
          disabled: forwarding[:disabled],
          base_url: axiom_cfg[:base_url],
          otel_endpoint: axiom_cfg[:otel_endpoint],
          queue: queue_stats
        }
      rescue StandardError
        @axiom = { dataset_url: nil, metrics_dataset_url: nil, traces_url: "https://app.axiom.co/traces" }
        @axiom_status = {
          env: AppConfig.environment,
          forwarding_allowed: false,
          forwarding_reason: :error,
          token_present: false,
          dataset_present: false,
          metrics_dataset_present: false,
          auto_forward: false,
          disabled: false,
          base_url: nil,
          otel_endpoint: nil,
          queue: StructuredLogger.forwarding_stats
        }
      end

      # Pipeline visibility (read-only manifest)
      @pipeline_manifest = if defined?(Profiles::PipelineManifest)
        Profiles::PipelineManifest.evaluated
      else
        []
      end

      @pipeline_snapshot_logins = available_pipeline_snapshot_logins
      preferred_login = params[:pipeline_login].presence&.downcase
      @pipeline_snapshot_login = preferred_login.presence || @pipeline_snapshot_logins.first
      @pipeline_snapshot = load_pipeline_snapshot(@pipeline_snapshot_login) if @pipeline_snapshot_login.present?
    end

    def update_ai_caps
      AppSetting.set_bool(:ai_images, ActiveModel::Type::Boolean.new.cast(params[:ai_images]))
      AppSetting.set_bool(:ai_image_descriptions, ActiveModel::Type::Boolean.new.cast(params[:ai_image_descriptions]))
      AppSetting.set_bool(:ai_text, ActiveModel::Type::Boolean.new.cast(params[:ai_text]))
      AppSetting.set_bool(:ai_structured_output, ActiveModel::Type::Boolean.new.cast(params[:ai_structured_output]))
      redirect_to ops_admin_path, notice: "AI capability flags updated"
    rescue StandardError => e
      redirect_to ops_admin_path, alert: "Failed to update AI flags: #{e.message}"
    end

    def rebuild_leaderboards
      kinds = Leaderboard::KINDS
      windows = Leaderboard::WINDOWS
      kinds.each do |k|
        windows.each do |w|
          Leaderboards::ComputeService.call(kind: k, window: w, as_of: Date.today)
        end
      end
      redirect_to ops_admin_path, notice: "Leaderboards rebuilt"
    end

    def capture_leaderboard_og
      Leaderboards::CaptureOgJob.perform_later(kind: params[:kind].presence || "followers_gain_30d", window: params[:window].presence || "30d")
      redirect_to ops_admin_path, notice: "Leaderboard OG capture enqueued"
    end

    def backups_create
      result = Backups::CreateService.call
      if result.success?
        redirect_to ops_admin_path, notice: "Backup uploaded (#{result.value[:keys].size} files)"
      else
        redirect_to ops_admin_path, alert: "Backup failed: #{result.error}"
      end
    end

    def backups_prune
      result = Backups::PruneService.call
      if result.success?
        redirect_to ops_admin_path, notice: "Pruned #{result.value[:deleted]} backup object(s)"
      else
        redirect_to ops_admin_path, alert: "Prune failed: #{result.error}"
      end
    end

    def backups_doctor
      result = Backups::DoctorService.call
      if result.success?
        meta = result.metadata
        msg = "Backup OK — bucket=#{meta[:bucket]} prefix=#{meta[:prefix]} region=#{meta[:region]} sample=#{meta[:sample_count]}"
        redirect_to ops_admin_path, notice: msg
      else
        redirect_to ops_admin_path, alert: "Backup check failed: #{result.error}"
      end
    end

    def backups_doctor_write
      unless params[:confirm].to_s == "YES"
        return redirect_to ops_admin_path, alert: "Confirm=YES required"
      end
      result = Backups::WriteProbeService.call
      if result.success?
        redirect_to ops_admin_path, notice: "Write probe ok — #{result.value[:key]}"
      else
        redirect_to ops_admin_path, alert: "Write probe failed: #{result.error}"
      end
    end

    # Access control: update allowed GitHub logins and open/closed toggle
    def update_access
      allowed = params[:allowed_logins].to_s.split(/[\s,]+/).map { |s| s.to_s.downcase.strip }.reject(&:blank?).uniq
      open_flag = ActiveModel::Type::Boolean.new.cast(params[:open_access])

      AppSetting.set_json(:allowed_logins, allowed)
      AppSetting.set_bool(:open_access, open_flag)

      redirect_to ops_admin_path, notice: "Access settings updated"
    rescue StandardError => e
      redirect_to ops_admin_path, alert: "Failed to update access: #{e.message}"
    end

    # Invite settings: cap and optional codes override
    def update_invites
      limit = params[:invite_cap_limit].to_s.strip
      used  = params[:invite_cap_used].to_s.strip
      codes = params[:invite_codes_override].to_s

      if limit.present?
        Integer(limit)
        AppSetting.set(:invite_cap_limit, limit)
      end

      if used.present?
        Integer(used)
        AppSetting.set(:invite_cap_used, used)
      end

      arr = codes.split(/[,\s]+/).map { |s| s.to_s.strip.downcase }.reject(&:blank?).uniq
      if arr.any?
        AppSetting.set_json(:sign_up_codes_override, arr)
      else
        # Clear override by setting to empty array
        AppSetting.set_json(:sign_up_codes_override, [])
      end

      redirect_to ops_admin_path, notice: "Invite settings updated"
    rescue ArgumentError
      redirect_to ops_admin_path, alert: "Invite settings invalid — limit/used must be integers"
    rescue StandardError => e
      redirect_to ops_admin_path, alert: "Failed to update invites: #{e.message}"
    end

    def send_test_email
      to = params[:to].presence
      message = params[:message]
      if to.blank?
        redirect_to ops_admin_path, alert: "Recipient is required"
        return
      end
      SystemMailer.with(to: to, message: message).smoke_test.deliver_later
      redirect_to ops_admin_path, notice: "Queued smoke test email to #{to}"
    end

    def bulk_retry
      logins = Array(params[:logins]).map { |s| s.to_s.downcase.strip }.reject(&:blank?)
      count = 0
      logins.each do |login|
        Profiles::GeneratePipelineJob.perform_later(login, trigger_source: "ops_admin#bulk_retry")
        count += 1
      end
      redirect_to ops_admin_path, notice: "Queued pipeline run for #{count} profile(s)."
    end

    # bulk_retry with images removed from Ops to avoid confusion and budget risk.

    def bulk_retry_all
      count = 0
      Profile.find_each do |p|
        Profiles::GeneratePipelineJob.perform_later(p.login, trigger_source: "ops_admin#bulk_retry_all")
        p.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
        count += 1
      end
      redirect_to ops_admin_path, notice: "Queued pipeline run for all (#{count}) profiles."
    end

    # bulk_retry_all with images removed from Ops to avoid confusion and budget risk.

    def bulk_refresh_assets
      logins = parse_logins(params[:logins])
      variants = normalized_variants(params[:variants])
      missing_only = boolean_param(params[:only_missing], default: true)
      desired_variants = variants.presence || Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS
      relation = logins.any? ? Profile.where(login: logins) : Profile.all

      count = 0
      relation.find_each do |profile|
        effective_variants = missing_only ? profile.missing_asset_variants(desired_variants) : desired_variants
        next if effective_variants.blank?

        overrides = Profiles::Pipeline::Recipes.screenshot_refresh(variants: effective_variants)
        next if overrides.blank?

        Profiles::GeneratePipelineJob.perform_later(
          profile.login,
          trigger_source: "ops_admin#bulk_refresh_assets",
          pipeline_overrides: overrides
        )
        profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
        count += 1
      end

      message = count.zero? ? "No profiles required asset refresh." : "Queued asset refresh for #{count} profile(s)."
      redirect_to ops_admin_path(anchor: "pipeline"), notice: message
    end

    def bulk_refresh_github
      logins = parse_logins(params[:logins])
      mode = params[:mode].to_s.presence || "github"
      overrides = case mode
      when "avatar"
        Profiles::Pipeline::Recipes.avatar_refresh
      else
        Profiles::Pipeline::Recipes.github_sync
      end
      if overrides.blank?
        return redirect_to ops_admin_path(anchor: "pipeline"), alert: "No recipe available for the requested GitHub refresh."
      end

      relation = logins.any? ? Profile.where(login: logins) : Profile.all
      count = 0
      relation.find_each do |profile|
        Profiles::GeneratePipelineJob.perform_later(
          profile.login,
          trigger_source: "ops_admin#bulk_refresh_github",
          pipeline_overrides: overrides
        )
        profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
        count += 1
      end

      message = count.zero? ? "No profiles were enqueued for GitHub refresh." : "Queued GitHub refresh for #{count} profile(s)."
      redirect_to ops_admin_path(anchor: "pipeline"), notice: message
    end

    # Removed write action for installation id: installation id must be configured explicitly.

    def axiom_smoke
      msg = params[:message].presence || "hello_world"
      if defined?(StructuredLogger)
        StructuredLogger.info({ message: "ops_axiom_smoke", sample: msg, request_id: request.request_id, env: Rails.env }, force_axiom: true)
      end
      redirect_to ops_admin_path, notice: "Emitted Axiom smoke log"
    end

    # Advanced: StructuredLogger test with level, message, payload, and force toggle
    def axiom_log_test
      level_param = params[:level].to_s.strip.downcase
      level = ALLOWED_LOG_LEVELS.include?(level_param) ? level_param : "info"
      message = params[:message].to_s.presence || "ops_axiom_test"
      force = ActiveModel::Type::Boolean.new.cast(params[:force])
      payload_json = params[:payload].to_s
      payload_hash = {}
      if payload_json.present?
        begin
          parsed = JSON.parse(payload_json)
          payload_hash = parsed.is_a?(Hash) ? parsed : { payload: parsed }
        rescue JSON::ParserError => e
          return redirect_to ops_admin_path(anchor: "ai"), alert: "Invalid JSON payload: #{e.message}"
        end
      end
      data = { message: message, source: "ops", env: Rails.env }.merge(payload_hash)
      if defined?(StructuredLogger) && StructuredLogger.respond_to?(level)
        StructuredLogger.public_send(level, data, force_axiom: force)
        redirect_to ops_admin_path(anchor: "ai"), notice: "Sent StructuredLogger #{level}"
      else
        redirect_to ops_admin_path(anchor: "ai"), alert: "Unknown log level: #{level}"
      end
    end

    # Direct ingest to a specified dataset (bypasses logger forwarding gates)
    def axiom_direct_ingest
      dataset = params[:dataset].to_s.presence || AppConfig.axiom[:dataset]
      body = params[:body].to_s
      if dataset.to_s.strip.empty?
        return redirect_to ops_admin_path(anchor: "ai"), alert: "Dataset is required"
      end
      begin
        parsed = JSON.parse(body.presence || "{}")
        events = parsed.is_a?(Array) ? parsed : [ parsed ]
      rescue JSON::ParserError => e
        return redirect_to ops_admin_path(anchor: "ai"), alert: "Invalid JSON body: #{e.message}"
      end
      res = Axiom::IngestService.call(dataset: dataset, events: events)
      if res.success?
        redirect_to ops_admin_path(anchor: "ai"), notice: "Ingested #{events.size} event(s) to #{dataset}"
      else
        redirect_to ops_admin_path(anchor: "ai"), alert: "Ingest failed: #{res.error.message}"
      end
    end

    # Emit an OTEL span with optional attributes and error flag
    def axiom_otel_smoke
      attrs_json = params[:attributes].to_s
      name = params[:name].presence || "ops_otel_smoke"
      error = ActiveModel::Type::Boolean.new.cast(params[:error])
      attributes = {}
      if attrs_json.present?
        begin
          parsed = JSON.parse(attrs_json)
          attributes = parsed.is_a?(Hash) ? parsed : { payload: parsed }
        rescue JSON::ParserError => e
          return redirect_to ops_admin_path(anchor: "ai"), alert: "Invalid attributes JSON: #{e.message}"
        end
      end
      begin
        require "opentelemetry/sdk"
        tracer = OpenTelemetry.tracer_provider.tracer("techub.ops", "1.0")
        tracer.in_span(name, attributes: attributes) do |span|
          if error
            span.record_exception(StandardError.new("ops_otel_smoke_error"))
            span.status = OpenTelemetry::Trace::Status.error("ops smoke error")
          end
          sleep 0.01
        end
        redirect_to ops_admin_path(anchor: "ai"), notice: "Emitted OTEL span"
      rescue LoadError
        redirect_to ops_admin_path(anchor: "ai"), alert: "OpenTelemetry not installed"
      rescue StandardError => e
        redirect_to ops_admin_path(anchor: "ai"), alert: "OTEL smoke failed: #{e.message}"
      end
    end

    def pipeline_doctor
      login = params[:login].to_s.downcase.presence
      host = params[:host].presence
      email = params[:email].presence
      variants = (params[:variants].presence || Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS.join(",")).to_s.split(/[,\s]+/).map(&:strip).reject(&:blank?)

      if login.blank?
        redirect_to ops_admin_path, alert: "Login is required"
        return
      end

      # Enqueue doctor job asynchronously so the request is fast and resilient
      Profiles::PipelineDoctorJob.perform_later(login: login, host: host, email: email, variants: variants)
      redirect_to ops_admin_path(anchor: "pipeline"), notice: "Pipeline doctor enqueued for @#{login}. Results will be emailed to ops."
    end

    def pipeline_snapshot
      login = params[:login].to_s.downcase
      file = params[:file].to_s

      if login.blank? || file.blank?
        redirect_to ops_admin_path(anchor: "pipeline"), alert: "Login and file are required"
        return
      end

      unless valid_safe_filename?(file)
        redirect_to ops_admin_path(anchor: "pipeline"), alert: "Invalid file requested"
        return
      end

      dir = latest_pipeline_snapshot_dir(login)
      unless dir&.exist?
        redirect_to ops_admin_path(anchor: "pipeline"), alert: "No snapshot found for @#{login}"
        return
      end

      dir_path = begin
        dir.realpath
      rescue StandardError
        redirect_to ops_admin_path(anchor: "pipeline"), alert: "No snapshot found for @#{login}"
        return
      end
      path = dir_path.join(file)

      unless path_within_directory?(dir_path, path)
        redirect_to ops_admin_path(anchor: "pipeline"), alert: "Invalid file requested"
        return
      end

      unless path.exist? && path.file?
        redirect_to ops_admin_path(anchor: "pipeline"), alert: "File not available in snapshot"
        return
      end

      real_path = begin
        path.realpath
      rescue StandardError
        redirect_to ops_admin_path(anchor: "pipeline"), alert: "File not available in snapshot"
        return
      end
      unless path_within_directory?(dir_path, real_path)
        redirect_to ops_admin_path(anchor: "pipeline"), alert: "Invalid file requested"
        return
      end

      send_file real_path, filename: "#{login}-#{file}"
    end

    private

    def parse_logins(values)
      case values
      when String
        values.split(/[,\s]+/)
      else
        Array(values)
      end.map { |login| login.to_s.downcase.strip }.reject(&:blank?).uniq
    end

    def normalized_variants(values)
      case values
      when String
        values.split(/[,\s]+/)
      else
        Array(values)
      end.map { |variant| variant.to_s.downcase.strip }.reject(&:blank?).uniq
    end

    def boolean_param(value, default: false)
      return default if value.nil?

      ActiveModel::Type::Boolean.new.cast(value)
    end

    def valid_safe_filename?(name)
      return false unless name.is_a?(String) && name.present?
      return false if name.include?("\0") || name.include?("..")
      return false unless name.match?(/\A[a-zA-Z0-9](?:[a-zA-Z0-9_.-]*[a-zA-Z0-9])?\z/)
      true
    end

    def path_within_directory?(base, target)
      relative = target.cleanpath.relative_path_from(base.cleanpath)
      relative.each_filename.none? { |segment| segment == ".." }
    rescue ArgumentError
      false
    end

    def tail_log(path, lines)
      file_path = Rails.root.join(path)
      return nil unless File.exist?(file_path)
      content = File.read(file_path)
      content.lines.last(lines).join
    rescue StandardError
      nil
    end

    def available_pipeline_snapshot_logins
      base = Rails.root.join("tmp", "pipeline_runs")
      Dir[base.join("*")].filter_map do |path|
        _, login = parse_snapshot_basename(File.basename(path))
        login
      end.uniq.sort
    rescue StandardError
      []
    end

    def latest_pipeline_snapshot_dir(login)
      return nil if login.blank?

      base = Rails.root.join("tmp", "pipeline_runs")
      pattern = base.join("*-#{login}")
      Dir[pattern.to_s]
        .select { |p| File.directory?(p) }
        .sort
        .reverse
        .map { |p| Pathname.new(p) }
        .first
    rescue StandardError
      nil
    end

    def load_pipeline_snapshot(login)
      dir = latest_pipeline_snapshot_dir(login)
      return nil unless dir && dir.exist?

      snapshot = read_snapshot_json(dir.join("pipeline_snapshot.json")) || {}
      {
        path: dir,
        metadata: read_snapshot_json(dir.join("metadata.json")) || {},
        stage_metadata: read_snapshot_json(dir.join("stage_metadata.json")) || snapshot[:stages] || {},
        snapshot: snapshot,
        trace: read_snapshot_json(dir.join("trace.json")),
        ai_prompt: read_snapshot_json(dir.join("ai_prompt.json")),
        ai_metadata: read_snapshot_json(dir.join("ai_metadata.json")),
        files: Dir.children(dir).sort
      }
    rescue StandardError
      nil
    end

    def parse_snapshot_basename(name)
      return [ nil, nil ] unless name.is_a?(String)
      parts = name.split("-", 2)
      return [ parts[0], parts[1]&.downcase ] if parts.length == 2
      [ nil, nil ]
    end

    def read_snapshot_json(path)
      return nil unless path.exist?

      content = File.read(path)
      JSON.parse(content, symbolize_names: true)
    rescue StandardError
      nil
    end
  end
end
