# OpenTelemetry setup (safe to load even if gems are missing)
begin
  # Allow environments to short-circuit OTEL entirely (e.g., when the upstream endpoint is broken).
  otel_disabled = ActiveModel::Type::Boolean.new.cast(ENV["OTEL_DISABLED"])
  if otel_disabled
    warn "[OTEL] Disabled via OTEL_DISABLED env flag." if ENV["OTEL_DEBUG"] == "1"
    raise LoadError
  end

  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/instrumentation/all"
  require "logger"

  # Silence OTEL internal logs unless explicitly debugging
  OpenTelemetry.logger ||= Logger.new($stderr)
  OpenTelemetry.logger.level = ENV["OTEL_DEBUG"] == "1" ? Logger::WARN : Logger::FATAL

  endpoint = ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].presence || (Rails.application.credentials.dig(:otel, :endpoint) rescue nil) || "https://api.axiom.co/v1/traces"
  token = (Rails.application.credentials.dig(:axiom, :token) rescue nil) || ENV["AXIOM_TOKEN"]
  base_dataset = (Rails.application.credentials.dig(:axiom, :dataset) rescue nil) || ENV["AXIOM_DATASET"]
  metrics_dataset = (Rails.application.credentials.dig(:axiom, :metrics_dataset) rescue nil) || ENV["AXIOM_METRICS_DATASET"] || base_dataset
  traces_dataset = (Rails.application.credentials.dig(:axiom, :traces_dataset) rescue nil) || ENV["AXIOM_TRACES_DATASET"] || metrics_dataset || base_dataset

  # If we lack endpoint or token, skip configuring OTEL entirely to avoid noisy warnings
  if endpoint.present? && token.present?
    base_headers = { "Authorization" => "Bearer #{token}" }
    traces_headers = base_headers.dup
    metrics_headers = base_headers.dup
    traces_headers["X-Axiom-Dataset"] = traces_dataset if traces_dataset.present?
    metrics_headers["X-Axiom-Dataset"] = metrics_dataset if metrics_dataset.present?
    base = endpoint.to_s.sub(%r{/v1/(traces|metrics|logs)$}, "")
    traces_endpoint = URI.join(base + "/", "v1/traces").to_s
    metrics_endpoint = URI.join(base + "/", "v1/metrics").to_s
    OpenTelemetry::SDK.configure do |c|
      c.service_name = "techub"
      c.service_version = (ENV["APP_VERSION"].presence || ENV["GIT_SHA"].presence || "").to_s
      c.use_all
      c.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint: traces_endpoint, headers: traces_headers)
        )
      )
      begin
        reader = OpenTelemetry::SDK::Metrics::Export::PeriodicExportingMetricReader.new(
          exporter: OpenTelemetry::Exporter::OTLP::MetricExporter.new(endpoint: metrics_endpoint, headers: metrics_headers),
          interval: (ENV["OTEL_METRICS_EXPORT_INTERVAL_MS"].presence || 60_000).to_i
        )
        c.add_metric_reader(reader)
      rescue StandardError => e
        warn "OTEL metrics setup failed: #{e.class}: #{e.message}" if ENV["OTEL_DEBUG"] == "1"
      end
    end

    begin
      meter = OpenTelemetry.meter_provider.meter("techub.metrics", "1.0")
      heartbeat = meter.create_counter("app_heartbeat_total", unit: "1", description: "Application heartbeat")
      unless defined?(OTEL_HEARTBEAT_THREAD)
        OTEL_HEARTBEAT_THREAD = Thread.new do
          loop do
            heartbeat.add(1, attributes: { env: Rails.env })
            sleep 60
          end
        end
      end
    rescue StandardError => e
      warn "OTEL heartbeat init failed: #{e.class}: #{e.message}" if ENV["OTEL_DEBUG"] == "1"
    end
  end
rescue LoadError
  # OTEL gems not installed; skip instrumentation
rescue StandardError => e
  # Suppress by default to avoid noisy logs; enable via OTEL_DEBUG=1 for troubleshooting
  warn "OTEL init failed: #{e.class}: #{e.message}" if ENV["OTEL_DEBUG"] == "1"
end
