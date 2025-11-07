# SolidQueue lifecycle spans (scheduler, dispatcher, recurring)
if defined?(SolidQueue)
  traced_events = {
    "enqueue_recurring_task.solid_queue" => "solid_queue.recurring.enqueue",
    "dispatch_scheduled.solid_queue" => "solid_queue.dispatch",
    "polling.solid_queue" => "solid_queue.poll",
    "claim.solid_queue" => "solid_queue.claim",
    "release_claimed.solid_queue" => "solid_queue.release"
  }.freeze

  traced_events.each do |event_name, span_name|
    ActiveSupport::Notifications.subscribe(event_name) do |name, start, finish, _id, payload|
      attributes = (payload || {}).each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value
      end
      attributes["solid_queue.event"] = name
      Observability::Tracing.record_notification_span(
        span_name,
        start_time: start,
        end_time: finish,
        attributes: attributes,
        tracer_key: :solid_queue
      )
    rescue StandardError => e
      if ENV["OTEL_DEBUG"] == "1"
        Rails.logger.debug("[OTEL] solid_queue span #{event_name} failed: #{e.class}: #{e.message}")
      end
    end
  end
end
