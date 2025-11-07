# Observability: Axiom and OpenTelemetry

This guide explains how to wire TecHub logs and traces to Axiom using JSON logs and OpenTelemetry
(OTEL).

## Logs → Axiom

- Current logging is JSON to STDOUT via `config/initializers/structured_logging.rb`.
- `AppConfig.axiom` centralises token, dataset, region, and trace URLs; the logger and ops panel
  read through it so runtime and doctor output stay consistent.
- If tokens/datasets are present, logs are forwarded to Axiom (best-effort) when
  `AppConfig.axiom_forwarding(force: false)[:allowed]` resolves to `true`.
- Configure (env or Rails credentials):
  - `AXIOM_TOKEN`: Axiom personal or ingest token (sensitive)
  - `AXIOM_ORG`: your org slug (e.g., `echosight-7xtu`) — non‑sensitive
  - `AXIOM_DATASET`: logs/events dataset (e.g., `techub`) — non‑sensitive
  - `AXIOM_TRACES_DATASET`: optional traces dataset override (defaults to the metrics dataset, then
    `AXIOM_DATASET`) — non‑sensitive
  - `AXIOM_METRICS_DATASET`: metrics dataset (e.g., `techub-metrics`). On the free plan, this also
    serves as the default destination for all OTEL traffic so logs and traces stay within the
    two‑dataset limit.
  - `AXIOM_BASE_URL`: region base URL (`https://api.axiom.co` US default, EU:
    `https://api.eu.axiom.co`)
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

- Exercise the StructuredLogger queue and forced/async delivery:

```bash
bin/rails axiom:runtime_doctor
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

- Set `AXIOM_TOKEN` and `AXIOM_DATASET` (usually via credentials). Forwarding runs automatically in
  production when both are present. In other environments, opt in with `AXIOM_ENABLED=1`.
- You can force a one-off send with `StructuredLogger.info(..., force_axiom: true)` (used by the
  runtime doctor task).

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

### Built-in span helpers

- `app/lib/observability/tracing.rb` exposes `Observability::Tracing.with_span` and helpers for
  recording notification spans or span events without littering controllers/jobs with OTEL API
  calls. It no-ops when OTEL is disabled, so you can safely wrap hot paths.
- Controllers should wrap expensive actions (e.g., `/directory`, `/submit`) with `with_span`,
  setting `tracer_key: :controller` and meaningful attributes (`http.route`, filters, pagination).
- Jobs automatically emit `job.perform` spans through `ApplicationJob`’s around hook. Each span
  carries `job.class`, `job.queue`, `job.id`, provider IDs, argument counts, and duration. Failures
  record exceptions and mark span status.
- SolidQueue lifecycle events (`enqueue_recurring_task`, `dispatch_scheduled`, `polling`, `claim`,
  `release_claimed`) are translated into spans via `config/initializers/solid_queue_tracing.rb`,
  letting you see scheduler bottlenecks without custom code.
- Recurring tasks now log and emit a `solid_queue.recurring.already_recorded` span event whenever a
  duplicate insert occurs. Pair this with the DB unique index migration
  (`db/migrate/20251015091500_add_unique_index_to_solid_queue_recurring_executions.rb`) to keep the
  noise out of error dashboards.

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
base_headers = { "Authorization" => "Bearer #{ENV["AXIOM_TOKEN"]}" }
traces_headers = base_headers.dup
metrics_headers = base_headers.dup
base_dataset = ENV["AXIOM_DATASET"]
metrics_dataset = ENV["AXIOM_METRICS_DATASET"].presence || base_dataset
traces_dataset = ENV["AXIOM_TRACES_DATASET"].presence || metrics_dataset || base_dataset
traces_headers["X-Axiom-Dataset"] = traces_dataset if traces_dataset.present?
metrics_headers["X-Axiom-Dataset"] = metrics_dataset if metrics_dataset.present?

OpenTelemetry::SDK.configure do |c|
  c.service_name = "techub"
  c.use_all()
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint: traces, headers: traces_headers)
    )
  )
  reader = OpenTelemetry::SDK::Metrics::Export::PeriodicExportingMetricReader.new(
    exporter: OpenTelemetry::Exporter::OTLP::MetricExporter.new(
      endpoint: metrics,
      headers: metrics_headers
    ),
    interval: (ENV["OTEL_METRICS_EXPORT_INTERVAL_MS"].presence || 60000).to_i
  )
  c.add_metric_reader(reader)
end
```

3. Env vars:

- `AXIOM_TOKEN`: token with tracing ingest permissions
- `AXIOM_DATASET`: base dataset used for logs (required for Axiom ingest). Also the fallback if you
  do not provide a separate metrics dataset.
- `AXIOM_METRICS_DATASET`: metrics/OTEL dataset. OTEL traces and metrics use this by default (to
  keep logs and traces within the two‑dataset free plan limit).
  - `AXIOM_TRACES_DATASET`: optional override for traces; falls back to `AXIOM_METRICS_DATASET`,
    then `AXIOM_DATASET`

  > **Plan note:** The free Axiom tier only includes two datasets. Keep `AXIOM_DATASET` for JSON
  > logs/direct ingest and point OTEL (traces + metrics) at `AXIOM_METRICS_DATASET` so everything
  > fits without buying more capacity.

- `OTEL_EXPORTER_OTLP_ENDPOINT`: optional; default above (US). EU:
  `https://api.eu.axiom.co/v1/traces`
- `OTEL_METRICS_EXPORT_INTERVAL_MS`: optional; metrics export interval (default 60000)

### Verify

- Traces: `rake axiom:otel_smoke` then open Ops → Axiom → OTEL Traces (service=techub)
- Metrics: `rake axiom:otel_metrics_smoke` or wait 1–2 min for `app_heartbeat_total`
- Missing the `X-Axiom-Dataset` header results in HTTP 200 responses with no stored data, so
  double-check the dataset env vars above if nothing appears in Axiom.

### Notes

- Prefer OTLP/HTTP for firewall simplicity.
- Sampling: default is always-on; reduce via `OTEL_TRACES_SAMPLER=parentbased_traceidratio` and
  `OTEL_TRACES_SAMPLER_ARG=0.2` for ~20% sampling.
- Privacy: avoid putting secrets in attributes; scrub PII.

### Span naming cheatsheet

| Span                                 | Source                         | Key attributes                                      |
| ------------------------------------ | ------------------------------ | --------------------------------------------------- |
| `pages.directory`                    | `PagesController#directory`    | `http.route=/directory`, filters counts, pagination |
| `pages.directory.tag_cloud`          | same                           | `directory.tag_cloud.count`, `...source_rows`       |
| `pages.directory.query`              | same                           | `directory.total`, `directory.returned`             |
| `submissions.create`                 | `SubmissionsController#create` | submission status, actor/user, enqueue_mode         |
| `job.perform`                        | `ApplicationJob` hook          | job ids, queue, duration, exception info            |
| `solid_queue.recurring.enqueue` etc. | SolidQueue notifications       | `task`, `at`, scheduler metadata                    |

Use these names when building dashboards or alerts (e.g., alert when `job.perform` P95 exceeds
300 ms for `Profiles::RefreshTagsJob`, or when `pages.directory` >700 ms).

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
