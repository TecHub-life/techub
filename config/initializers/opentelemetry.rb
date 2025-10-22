# OpenTelemetry setup (safe to load even if gems are missing)
begin
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/instrumentation/all"
  require "logger"

  # Silence OTEL internal logs unless explicitly debugging
  OpenTelemetry.logger ||= Logger.new($stderr)
  OpenTelemetry.logger.level = ENV["OTEL_DEBUG"] == "1" ? Logger::WARN : Logger::FATAL

  endpoint = ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].presence || (Rails.application.credentials.dig(:otel, :endpoint) rescue nil) || "https://api.axiom.co/v1/traces"
  token = (Rails.application.credentials.dig(:axiom, :token) rescue nil) || ENV["AXIOM_TOKEN"]

  # If we lack endpoint or token, skip configuring OTEL entirely to avoid noisy warnings
  if endpoint.present? && token.present?
    headers = { "Authorization" => "Bearer #{token}" }
    OpenTelemetry::SDK.configure do |c|
      c.service_name = (ENV["OTEL_SERVICE_NAME"].presence || "techub").to_s
      c.service_version = (ENV["APP_VERSION"].presence || ENV["GIT_SHA"].presence || "").to_s
      c.use_all
      c.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint: endpoint, headers: headers)
        )
      )
    end
  end
rescue LoadError
  # OTEL gems not installed; skip instrumentation
rescue StandardError => e
  # Suppress by default to avoid noisy logs; enable via OTEL_DEBUG=1 for troubleshooting
  warn "OTEL init failed: #{e.class}: #{e.message}" if ENV["OTEL_DEBUG"] == "1"
end
