# Observability: Axiom and OpenTelemetry

This guide explains how to wire TecHub logs and traces to Axiom using JSON logs and OpenTelemetry
(OTEL).

## Logs → Axiom

- Current logging is JSON to STDOUT via `config/initializers/structured_logging.rb`.
- If `AXIOM_TOKEN` and `AXIOM_DATASET` are set, logs are also sent to Axiom (best-effort) via
  Faraday.
- Configure:
  - `AXIOM_TOKEN`: Axiom personal or ingest token
  - `AXIOM_DATASET`: target dataset name
- In production, deploy with these env vars to enable forwarding.

### Log fields

- Base fields: `ts`, `level`, `request_id`, `user_id`, `ip`, `ua`, `path`, `method`
- Payload: arbitrary keys depending on call site
- Emit programmatically via `StructuredLogger.info/warn/error/debug(hash_or_message, extra: ...)`.

## Traces (OpenTelemetry)

We recommend enabling OTEL for Rails, ActiveRecord, and HTTP clients, exporting to Axiom’s OTEL
endpoint via OTLP/HTTP.

### Setup

1. Add gems:

```ruby
# Gemfile
gem "opentelemetry-sdk"
gem "opentelemetry-exporter-otlp"
gem "opentelemetry-instrumentation-all"
```

2. Initialize OTEL:

```ruby
# config/initializers/opentelemetry.rb
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

OpenTelemetry::SDK.configure do |c|
  c.service_name = "techub"
  c.use_all() # Rails, ActiveRecord, Faraday, etc.
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT", "https://api.axiom.co/v1/traces"),
        headers: { "Authorization" => "Bearer #{ENV["AXIOM_TOKEN"]}" }
      )
    )
  )
end
```

3. Env vars:

- `AXIOM_TOKEN`: token with tracing ingest permissions
- `OTEL_EXPORTER_OTLP_ENDPOINT`: optional; default above

### Notes

- Prefer OTLP/HTTP for firewall simplicity.
- Sampling: default is always-on; reduce via `OTEL_TRACES_SAMPLER=parentbased_traceidratio` and
  `OTEL_TRACES_SAMPLER_ARG=0.2` for ~20% sampling.
- Privacy: avoid putting secrets in attributes; scrub PII.

## Dashboards & queries

- In Axiom, create views for error rates, request latency, queue times, and generation failures.
- Add a link from `/ops` to Axiom dataset and traces view.

## Local dev

- Leave `AXIOM_TOKEN` unset to disable forwarding; logs remain on STDOUT.
- You can run a local OTEL collector and set `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318`.
