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
