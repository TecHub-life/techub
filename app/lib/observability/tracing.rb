module Observability
  module Tracing
    extend self

    DEFAULT_TRACERS = {
      default: { name: "techub.app", version: "1.0" },
      controller: { name: "techub.http", version: "1.0" },
      jobs: { name: "techub.jobs", version: "1.0" },
      solid_queue: { name: "techub.solid_queue", version: "1.0" }
    }.freeze

    def with_span(name, attributes: {}, tracer_key: :default, kind: nil)
      tracer = tracer_for(tracer_key)
      if tracer
        tracer.in_span(name, attributes: sanitize(attributes), kind: kind) do |span|
          yield span
        end
      else
        yield nil
      end
    end

    def record_notification_span(name, start_time:, end_time:, attributes: {}, tracer_key: :default)
      tracer = tracer_for(tracer_key)
      return unless tracer
      span = tracer.start_root_span(name, attributes: sanitize(attributes), start_timestamp: start_time)
      span.finish(end_timestamp: end_time)
      span
    rescue StandardError => e
      debug("notification_span_failed #{name}", e)
      nil
    end

    def add_event(span, name, attributes: {})
      span&.add_event(name, attributes: sanitize(attributes))
    end

    private

    def tracer_for(key)
      return unless defined?(OpenTelemetry)
      cfg = DEFAULT_TRACERS[key] || DEFAULT_TRACERS[:default]
      cached_tracers[key] ||= OpenTelemetry.tracer_provider.tracer(cfg[:name], cfg[:version])
    rescue StandardError => e
      debug("tracer_init_failed #{key}", e)
      nil
    end

    def cached_tracers
      @cached_tracers ||= {}
    end

    def sanitize(attrs)
      attrs.each_with_object({}) do |(key, value), memo|
        next if value.nil?
        memo[key.to_s] = coerce(value)
      end
    end

    def coerce(value)
      case value
      when Time
        value.iso8601(6)
      when Date, DateTime
        value.iso8601
      when Hash
        value.transform_values { |v| coerce(v) }
      when Array
        value.map { |v| coerce(v) }
      else
        value
      end
    end

    def debug(message, error)
      return unless ENV["OTEL_DEBUG"] == "1"
      Rails.logger.debug("[OTEL] #{message}: #{error.class}: #{error.message}")
    rescue StandardError
    end
  end
end
