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

      # Profiles that claim success but are missing expected associated data
      begin
        candidates = Profile.where(last_pipeline_status: "success").includes(:profile_card, :profile_languages, :profile_repositories)
        @data_issues_profiles = candidates.select do |p|
          p.profile_card.nil? || !p.profile_languages.exists? || !p.profile_repositories.exists?
        end.first(50)
      rescue StandardError
        @data_issues_profiles = []
      end
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
        Profiles::GeneratePipelineJob.perform_later(login, ai: false)
        count += 1
      end
      redirect_to ops_admin_path, notice: "Queued no-AI re-run for #{count} profile(s)"
    end

    def bulk_retry_ai
      logins = Array(params[:logins]).map { |s| s.to_s.downcase.strip }.reject(&:blank?)
      count = 0
      now = Time.current
      Profile.where(login: logins).find_each do |p|
        Profiles::GeneratePipelineJob.perform_later(p.login, ai: true)
        p.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil, last_ai_regenerated_at: now)
        count += 1
      end
      redirect_to ops_admin_path, notice: "Queued AI re-run for #{count} profile(s)"
    end

    private

    def tail_log(path, lines)
      file_path = Rails.root.join(path)
      return nil unless File.exist?(file_path)
      content = File.read(file_path)
      content.lines.last(lines).join
    rescue StandardError
      nil
    end
  end
end
