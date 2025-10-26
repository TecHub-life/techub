# Observability: Axiom and OpenTelemetry

This guide explains how to wire TecHub logs and traces to Axiom using JSON logs and OpenTelemetry
(OTEL).

## Logs → Axiom

- Current logging is JSON to STDOUT via `config/initializers/structured_logging.rb`.
- If `AXIOM_TOKEN` and `AXIOM_DATASET` are set, logs are also sent to Axiom (best-effort) via
  the shared ingest client.
- Configure (env or Rails credentials):
  - `AXIOM_TOKEN`: Axiom personal or ingest token (sensitive)
  - `AXIOM_ORG`: your org slug (e.g., `echosight-7xtu`) — non‑sensitive
  - `AXIOM_DATASET`: logs/events dataset (e.g., `techub`) — non‑sensitive
  - `AXIOM_METRICS_DATASET`: metrics dataset (e.g., `techub-metrics`) — non‑sensitive
  - `AXIOM_BASE_URL`: region base URL (`https://api.axiom.co` US default, EU: `https://api.eu.axiom.co`)
  - `OTEL_EXPORTER_OTLP_ENDPOINT`: traces endpoint (defaults to `https://api.axiom.co/v1/traces`;
    use EU endpoint if applicable)
  - `OTEL_SERVICE_NAME`: service name for traces (defaults to `techub`)
  - Optional UI links (override): `AXIOM_DATASET_URL`, `AXIOM_METRICS_DATASET_URL`,
    `AXIOM_TRACES_URL`

  In production, deploy with these variables to enable forwarding.

Quick doctor

- Test direct ingest (prints HTTP status):

```bash
bin/rails axiom:doctor
```

- Emit StructuredLogger smoke (uses force_axiom):

```bash
bin/rails 'axiom:smoke[hello_world]'
```

- If you set `AXIOM_METRICS_DATASET`, the doctor also sends a metrics probe event.

### Log fields

- Base fields: `ts`, `level`, `request_id`, `job_id`, `app_version`, `user_id`, `ip`, `ua`, `path`,
  `method`, `trace_id`, `span_id`, `_time`
- Payload: arbitrary keys depending on call site
- Emit programmatically via `StructuredLogger.info/warn/error/debug(hash_or_message, extra: ...)`.

Release correlation

- Set `APP_VERSION` (preferred) or `GIT_SHA` in the environment to annotate every log with
  `app_version`.
  - Example (Kamal): `APP_VERSION=$(git rev-parse --short HEAD) bin/kamal deploy`

Job correlation

- All ActiveJob runs include `job_id` automatically and log `job_start`, `job_finish`, and
  `job_error` with durations.

Forwarding controls

- Set `AXIOM_TOKEN` and `AXIOM_DATASET` to enable log forwarding (best-effort; failures are
  swallowed).
- Forwarding is on in production by default; to enable in other envs set `AXIOM_ENABLED=1`.
- You can force a one-off send with `StructuredLogger.info(..., force_axiom: true)`.
- For troubleshooting, set `AXIOM_DEBUG=1` to print skip/exception reasons to STDERR.

### CI and Deploy Telemetry

- GitHub Actions emits deployment and CI events to Axiom when `AXIOM_TOKEN` and `AXIOM_DATASET` are
  present as repository secrets.
  - Optional: `AXIOM_BASE_URL` secret to target EU region, otherwise defaults to US.
- CI emits:
  - `ci_start`, `ci_success`, `ci_failed` for the test job
  - `ci_image_built` with image `name` and `digest`
  - `ci_sbom_attested` after SBOM attestation succeeds
- Deploy emits:
  - `deploy_start`, `deploy_success`, `deploy_failed` around Kamal deploys
- All events include: `repo`, `ref`, `sha`, `actor`, `run_url` for correlation.
- Locations:
  - CI workflow: `.github/workflows/ci.yml`
  - Deploy workflow: `.github/workflows/kamal-deploy.yml`
- Secrets required: `AXIOM_TOKEN`, `AXIOM_DATASET`
- Optional:
  - Email on deploy failure via Resend (`RESEND_API_KEY`, `TO_EMAIL`)

#### Queries / Dashboards

- CI reliability: group by `message` and `repo`, chart success/error counts over time.
- Release quality: filter `deploy_*` events and correlate durations.
- Supply-chain visibility: join `ci_image_built` and `ci_sbom_attested` by `image.digest`.

## Traces & Metrics (OpenTelemetry)

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

2. Initialize OTEL (traces + metrics):

```ruby
# config/initializers/opentelemetry.rb
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

base = ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].presence || "https://api.axiom.co/v1/traces"
base = base.sub(%r{/v1/(traces|metrics|logs)$}, "")
traces = base + "/v1/traces"
metrics = base + "/v1/metrics"

OpenTelemetry::SDK.configure do |c|
  c.service_name = "techub"
  c.use_all()
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: traces,
        headers: { "Authorization" => "Bearer #{ENV["AXIOM_TOKEN"]}" }
      )
    )
  )
  reader = OpenTelemetry::SDK::Metrics::Export::PeriodicExportingMetricReader.new(
    exporter: OpenTelemetry::Exporter::OTLP::MetricExporter.new(
      endpoint: metrics,
      headers: { "Authorization" => "Bearer #{ENV["AXIOM_TOKEN"]}" }
    ),
    interval: (ENV["OTEL_METRICS_EXPORT_INTERVAL_MS"].presence || 60000).to_i
  )
  c.add_metric_reader(reader)
end
```

3. Env vars:

- `AXIOM_TOKEN`: token with tracing ingest permissions
- `OTEL_EXPORTER_OTLP_ENDPOINT`: optional; default above (US). EU:
  `https://api.eu.axiom.co/v1/traces`
- `OTEL_METRICS_EXPORT_INTERVAL_MS`: optional; metrics export interval (default 60000)

### Verify

- Traces: `rake axiom:otel_smoke` then open Ops → Axiom → OTEL Traces (service=techub)
- Metrics: `rake axiom:otel_metrics_smoke` or wait 1–2 min for `app_heartbeat_total`

### Notes

- Prefer OTLP/HTTP for firewall simplicity.
- Sampling: default is always-on; reduce via `OTEL_TRACES_SAMPLER=parentbased_traceidratio` and
  `OTEL_TRACES_SAMPLER_ARG=0.2` for ~20% sampling.
- Privacy: avoid putting secrets in attributes; scrub PII.

## Dashboards & queries

- In Axiom, create views for error rates, request latency, queue times, and generation failures.
- Ops panel links (auto-constructed when `AXIOM_ORG` and datasets are set):
  - Logs dataset: `https://app.axiom.co/${AXIOM_ORG}/datasets/${AXIOM_DATASET}`
  - Metrics dataset: `https://app.axiom.co/${AXIOM_ORG}/datasets/${AXIOM_METRICS_DATASET}`
  - Traces: `https://app.axiom.co/${AXIOM_ORG}/traces?service=${OTEL_SERVICE_NAME}`

## Local dev

- Leave `AXIOM_TOKEN` unset to disable forwarding; logs remain on STDOUT.
- You can run a local OTEL collector and set `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318`.

### Built-in application metrics

- HTTP
  - http_server_requests_total — count by http.method, http.status_code, controller, action, route,
    env
  - http_server_request_errors_total — count of 5xx/exceptions by same attrs
  - http_server_request_duration_ms — histogram of request duration
- Database
  - db_queries_total — count by adapter, name, env (excludes SCHEMA/TRANSACTION)
  - db_query_duration_ms — histogram
- Jobs
  - job_enqueued_total — count by job, queue, env
  - job_performed_total — count by job, queue, env
  - job_failed_total — count by job, queue, env
  - job_duration_ms — histogram
- Process
  - process_resident_memory_bytes — gauge
  - process_threads — gauge

Query tips

- Error rate by controller: filter http.status_code >= 500, group by controller, action
- P95 request latency: percentile(http_server_request_duration_ms, 95) by controller, action
- DB pressure: sum(db_queries_total) by name over 5m
- Queue health: sum(job_failed_total) vs sum(job_performed_total) by job over 1h
