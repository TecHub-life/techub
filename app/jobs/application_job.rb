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
    span_attrs = {
      "job.class" => job.class.name,
      "job.id" => job.job_id,
      "job.queue" => job.queue_name,
      "job.provider_id" => job.try(:provider_job_id),
      "job.arguments.count" => job.arguments.size
    }
    Observability::Tracing.with_span("job.perform", attributes: span_attrs, tracer_key: :jobs) do |span|
      Observability::Tracing.add_event(span, "job.args_preview", attributes: { preview: args_preview })
      begin
        StructuredLogger.info(message: "job_start", job_class: job.class.name, job_id: job.job_id, queue_name: job.queue_name, args_preview: args_preview)
        block.call
        duration_ms = elapsed_ms(started)
        span&.set_attribute("job.duration_ms", duration_ms)
        StructuredLogger.info(message: "job_finish", job_class: job.class.name, job_id: job.job_id, queue_name: job.queue_name, duration_ms: duration_ms)
      rescue => e
        duration_ms = elapsed_ms(started)
        span&.record_exception(e)
        span&.set_attribute("job.duration_ms", duration_ms)
        span&.status = OpenTelemetry::Trace::Status.error("job_failed") if defined?(OpenTelemetry::Trace::Status)
        StructuredLogger.error(message: "job_error", job_class: job.class.name, job_id: job.job_id, queue_name: job.queue_name, duration_ms: duration_ms, error_class: e.class.name, error: e.message)
        raise
      end
    end
  ensure
    Current.job_id = prev
  end

  private

  def elapsed_ms(started_at)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
  end
end
