module Ops
  class JobsController < ApplicationController
    before_action :require_jobs_basic_auth

    def index
      @adapter = ActiveJob::Base.queue_adapter
      @engine_present = defined?(MissionControl::Jobs::Engine)

      @stats = {
        queued: nil,
        ready: nil,
        running: nil,
        failed: nil,
        finished_last_hour: nil,
        processes: []
      }

      if defined?(SolidQueue)
        begin
          @stats[:queued] = (SolidQueue::Job.where(finished_at: nil).count rescue nil)
          @stats[:ready] = (SolidQueue::ReadyExecution.count rescue nil)
          @stats[:running] = (SolidQueue::ClaimedExecution.count rescue nil)
          @stats[:failed] = (SolidQueue::FailedExecution.count rescue nil)
          @stats[:finished_last_hour] = (SolidQueue::Job.where.not(finished_at: nil).where("finished_at > ?", 1.hour.ago).count rescue nil)
          @stats[:processes] = (SolidQueue::Process.order(last_heartbeat_at: :desc).limit(10).to_a rescue [])
        rescue StandardError => e
          @error = e.message
        end
      end

      # Recent pipeline stage events
      begin
        @recent_events = ProfilePipelineEvent.includes(:profile).order(created_at: :desc).limit(50)
      rescue StandardError
        @recent_events = []
      end
    end

    private

    def require_jobs_basic_auth
      basic = ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] || Rails.application.credentials.dig(:mission_control, :jobs, :http_basic)
      # In production, always require auth even if credentials are missing
      if Rails.env.production?
        authenticate_or_request_with_http_basic("TecHub Jobs") do |u, p|
          user, pass = (basic.to_s.split(":", 2))
          ActiveSupport::SecurityUtils.secure_compare(u.to_s, user.to_s) &
            ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass.to_s)
        end
      elsif basic.present?
        authenticate_or_request_with_http_basic("TecHub Jobs") do |u, p|
          user, pass = (basic.to_s.split(":", 2))
          ActiveSupport::SecurityUtils.secure_compare(u.to_s, user.to_s) &
            ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass.to_s)
        end
      end
    end
  end
end
