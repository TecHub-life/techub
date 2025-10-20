class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  around_perform do |job, block|
    prev = Current.job_id
    Current.job_id = job.job_id
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    args_preview = Array(job.arguments).map { |a| a.is_a?(Hash) ? a.keys : a.class.name }.first(3)
    begin
      StructuredLogger.info(message: "job_start", job_class: job.class.name, job_id: job.job_id, queue_name: job.queue_name, args_preview: args_preview)
      block.call
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).to_i
      StructuredLogger.info(message: "job_finish", job_class: job.class.name, job_id: job.job_id, queue_name: job.queue_name, duration_ms: duration_ms)
    rescue => e
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).to_i
      StructuredLogger.error(message: "job_error", job_class: job.class.name, job_id: job.job_id, queue_name: job.queue_name, duration_ms: duration_ms, error_class: e.class.name, error: e.message)
      raise
    ensure
      Current.job_id = prev
    end
  end
end
