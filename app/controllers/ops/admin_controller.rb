module Ops
  class AdminController < BaseController
    def index
      @engine_present = defined?(MissionControl::Jobs::Engine)
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
      rescue StandardError
        @failed_profiles = []
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

      # Pipeline visibility (read-only manifest)
      @pipeline_manifest = if defined?(Profiles::PipelineManifest)
        Profiles::PipelineManifest.evaluated
      else
        []
      end
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
        Profiles::GeneratePipelineJob.perform_later(login, images: false)
        count += 1
      end
      redirect_to ops_admin_path, notice: "Queued re-run (no new images) for #{count} profile(s) — text AI always on"
    end

    # bulk_retry with images removed from Ops to avoid confusion and budget risk.

    def bulk_retry_all
      count = 0
      Profile.find_each do |p|
        Profiles::GeneratePipelineJob.perform_later(p.login, images: false)
        p.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
        count += 1
      end
      redirect_to ops_admin_path, notice: "Queued re-run (no new images) for all (#{count}) profiles — text AI always on"
    end

    # bulk_retry_all with images removed from Ops to avoid confusion and budget risk.

    # Removed write action for installation id: installation id must be configured explicitly.

    private

    def tail_log(path, lines)
      file_path = Rails.root.join(path)
      return nil unless File.exist?(file_path)
      content = File.read(file_path)
      content.lines.last(lines).join
    rescue StandardError
      nil
    end

    def axiom_smoke
      msg = params[:message].presence || "hello_world"
      if defined?(StructuredLogger)
        StructuredLogger.info({ message: "ops_axiom_smoke", sample: msg, request_id: request.request_id, env: Rails.env }, force_axiom: true)
      end
      redirect_to ops_admin_path, notice: "Emitted Axiom smoke log"
    end
  end
end
