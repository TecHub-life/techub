# OpenTelemetry application metrics (HTTP, DB, Jobs, Process)
begin
  require "opentelemetry/sdk"
  require "active_support/notifications"

  meter = OpenTelemetry.meter_provider.meter("techub.metrics", "1.0")

  # HTTP server metrics (Rails controller layer)
  http_req_total = meter.create_counter(
    "http_server_requests_total",
    unit: "1",
    description: "Total number of HTTP requests"
  )
  http_req_errors_total = meter.create_counter(
    "http_server_request_errors_total",
    unit: "1",
    description: "Total number of failed HTTP requests"
  )
  http_req_duration = meter.create_histogram(
    "http_server_request_duration_ms",
    unit: "ms",
    description: "HTTP request duration"
  )

  ActiveSupport::Notifications.subscribe("process_action.action_controller") do |_name, start, finish, _id, payload|
    begin
      duration_ms = ((finish - start) * 1000.0)
      status = (payload[:status] || 500).to_i
      controller = payload[:controller].to_s
      action = payload[:action].to_s
      method = payload[:method].to_s.upcase
      route = payload[:path].to_s
      attrs = { "http.method" => method, "http.status_code" => status, controller: controller, action: action, route: route, env: Rails.env }
      http_req_total.add(1, attributes: attrs)
      http_req_duration.record(duration_ms, attributes: attrs)
      if payload[:exception] || status.to_i >= 500
        http_req_errors_total.add(1, attributes: attrs)
      end
    rescue StandardError
    end
  end

  # ActiveRecord SQL metrics
  db_query_total = meter.create_counter(
    "db_queries_total",
    unit: "1",
    description: "Total number of SQL queries executed"
  )
  db_query_duration = meter.create_histogram(
    "db_query_duration_ms",
    unit: "ms",
    description: "SQL query duration"
  )

  ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|
    begin
      name = payload[:name].to_s
      return if name == "SCHEMA" || name == "TRANSACTION"
      duration_ms = ((finish - start) * 1000.0)
      adapter = ActiveRecord::Base.connection_db_config.adapter.to_s rescue "unknown"
      attrs = { adapter: adapter, name: name, env: Rails.env }
      db_query_total.add(1, attributes: attrs)
      db_query_duration.record(duration_ms, attributes: attrs)
    rescue StandardError
    end
  end

  # ActiveJob metrics
  job_enqueued_total = meter.create_counter(
    "job_enqueued_total",
    unit: "1",
    description: "Total jobs enqueued"
  )
  job_performed_total = meter.create_counter(
    "job_performed_total",
    unit: "1",
    description: "Total jobs performed"
  )
  job_failed_total = meter.create_counter(
    "job_failed_total",
    unit: "1",
    description: "Total jobs failed"
  )
  job_duration = meter.create_histogram(
    "job_duration_ms",
    unit: "ms",
    description: "Job perform duration"
  )

  ActiveSupport::Notifications.subscribe("enqueue.active_job") do |_name, _start, _finish, _id, payload|
    begin
      job_class = payload[:job].class.name rescue payload[:job]&.to_s
      queue = payload[:job].queue_name rescue payload[:queue]
      attrs = { job: job_class.to_s, queue: queue.to_s, env: Rails.env }
      job_enqueued_total.add(1, attributes: attrs)
    rescue StandardError
    end
  end

  ActiveSupport::Notifications.subscribe("perform.active_job") do |_name, start, finish, _id, payload|
    begin
      duration_ms = ((finish - start) * 1000.0)
      job_class = payload[:job].class.name rescue payload[:job]&.to_s
      queue = payload[:job].queue_name rescue payload[:queue]
      attrs = { job: job_class.to_s, queue: queue.to_s, env: Rails.env }
      job_performed_total.add(1, attributes: attrs)
      job_duration.record(duration_ms, attributes: attrs)
    rescue StandardError
    end
  end

  # Best-effort failure counter via ActiveJob around hook if available
  if defined?(ActiveJob::Base)
    module OtelJobFailureHook
      def self.included(base)
        base.around_perform do |job, block|
          begin
            block.call
          rescue StandardError
            begin
              attrs = { job: job.class.name.to_s, queue: job.queue_name.to_s, env: Rails.env }
              job_failed_total.add(1, attributes: attrs)
            rescue StandardError
            end
            raise
          end
        end
      end
    end
    ActiveSupport.on_load(:active_job) { ActiveJob::Base.include(OtelJobFailureHook) }
  end

  # Process metrics (observables)
  meter.create_observable_gauge(
    "process_resident_memory_bytes",
    unit: "By",
    description: "Resident set size (bytes)"
  ) do |observer|
    begin
      rss_bytes = nil
      if File.exist?("/proc/self/status")
        File.read("/proc/self/status").each_line do |line|
          if line.start_with?("VmRSS:")
            parts = line.split
            # VmRSS: <value> kB
            rss_kb = parts[1].to_i
            rss_bytes = rss_kb * 1024
            break
          end
        end
      end
      rss_bytes ||= (`ps -o rss= -p #{Process.pid}`.to_i * 1024 rescue nil)
      if rss_bytes
        observer.observe(rss_bytes, attributes: { env: Rails.env })
      end
    rescue StandardError
    end
  end

  meter.create_observable_gauge(
    "process_threads",
    unit: "1",
    description: "Number of Ruby threads"
  ) do |observer|
    begin
      observer.observe(Thread.list.count, attributes: { env: Rails.env })
    rescue StandardError
    end
  end
rescue LoadError
  # OpenTelemetry not installed; skip
rescue StandardError => e
  warn "OTEL metrics init failed: #{e.class}: #{e.message}" if ENV["OTEL_DEBUG"] == "1"
end
