if defined?(SolidQueue::RecurringExecution)
  module SolidQueue
    module RecurringExecutionIdempotency
      def create_or_insert!(**attributes)
        super
      rescue ActiveRecord::StatementInvalid => e
        if constraint_error?(e)
          log_duplicate(attributes)
          raise AlreadyRecorded
        else
          raise
        end
      end

      def record(task_key, run_at, &block)
        super
      rescue AlreadyRecorded => e
        log_duplicate(task_key: task_key, run_at: run_at)
        span = defined?(OpenTelemetry::Trace) ? OpenTelemetry::Trace.current_span : nil
        Observability::Tracing.add_event(
          span,
          "solid_queue.recurring.already_recorded",
          attributes: { task_key: task_key, run_at: run_at }
        )
        raise
      end

      private

      def constraint_error?(error)
        message = error.message.to_s
        message.include?("solid_queue_recurring_executions") || message.include?("UNIQUE constraint failed")
      end

      def log_duplicate(attributes)
        return unless defined?(StructuredLogger)
        StructuredLogger.warn(
          { message: "solid_queue_recurring_already_recorded", task_key: attributes[:task_key], run_at: attributes[:run_at] },
          component: "solid_queue",
          event: "solid_queue.recurring.already_recorded"
        )
      end
    end
  end

  SolidQueue::RecurringExecution.singleton_class.prepend(SolidQueue::RecurringExecutionIdempotency)
end
