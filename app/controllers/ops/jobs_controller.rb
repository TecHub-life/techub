module Ops
  class JobsController < ApplicationController
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
    end
  end
end
