# Observability: Axiom and OpenTelemetry

This guide explains how to wire TecHub logs and traces to Axiom using JSON logs and OpenTelemetry
(OTEL).

## Logs → Axiom

- Current logging is JSON to STDOUT via `config/initializers/structured_logging.rb`.
- `AppConfig.axiom` centralises token, dataset, region, and trace URLs; the logger and Ops panel
  read through it so runtime and doctor output stay consistent.
- The only Axiom secret is the ingest token. It lives in Rails credentials (`axiom.token`) and is
  copied to `AXIOM_TOKEN` at boot. All other values are non‑secret defaults baked into
  `AppConfig.axiom` and can be overridden with env vars when needed.
- Dataset layout (keeps us within the two-dataset allowance on Axiom’s free tier):
  - `otel-logs`: StructuredLogger output, CI/deploy events, and any structured JSON we push
    directly. Override via `AXIOM_DATASET`.
  - `otel-traces`: OpenTelemetry traces today and metrics once Axiom enables OTEL metrics. Override
    via `AXIOM_TRACES_DATASET` (and optionally `AXIOM_METRICS_DATASET`, which defaults to the same
    value).
- Additional non-secret knobs:
  - `AXIOM_ORG`: org slug for Ops deep links (default `echosight-7xtu`)
  - `AXIOM_BASE_URL`: region base URL (`https://api.axiom.co` US default, EU
    `https://api.eu.axiom.co`)
  - `OTEL_EXPORTER_OTLP_ENDPOINT`: OTLP base endpoint (defaults to `<base_url>/v1/traces`)
  - Optional UI overrides: `AXIOM_DATASET_URL`, `AXIOM_METRICS_DATASET_URL`,
    `AXIOM_TRACES_DATASET_URL`, `AXIOM_TRACES_URL`
- If `AXIOM_TOKEN` is present, `AppConfig.axiom_forwarding(force: false)` automatically enables
  forwarding in production; other environments can opt in via `AXIOM_ENABLED=1`.

### Why exactly two datasets?

- Axiom’s free tier includes two datasets. Using `otel-logs` for everything JSON and `otel-traces`
  for OTEL lets us stay within that allowance without sacrificing signal.
- When Axiom enables OTEL metrics, they’ll piggyback on `otel-traces` so we still occupy two
  datasets.
- If you need additional segmentation later, flip the env vars (`AXIOM_DATASET`,
  `AXIOM_TRACES_DATASET`) without touching credentials.

Quick doctor

- Test direct ingest (prints HTTP status):

```bash
bin/rails axiom:doctor
```

- Output now includes the source of each dataset (ENV override vs AppConfig default). If it still
  shows `techub`, check for leftover `AXIOM_DATASET` / `AXIOM_TRACES_DATASET` env vars lingering in
  your shell or `.env`.

- Exercise the StructuredLogger queue and forced/async delivery:

```bash
bin/rails axiom:runtime_doctor
```

- Forwarding is disabled outside production by default; set `AXIOM_ENABLED=1` when you need to run
  this in development/staging.

- Emit StructuredLogger smoke (uses force_axiom):

```bash
bin/rails 'axiom:smoke[hello_world]'
```

- If you set `AXIOM_METRICS_DATASET`, the doctor also sends a metrics probe event.
- Primary smoke (structured log + OTEL trace + direct ingest):

```bash
bin/rails axiom:smoke_all   # alias for axiom:self_test
```

This runs the forced StructuredLogger log, emits an OTEL span, and performs a direct ingest call —
so you cover both datasets plus traces with one command.

- `bin/rails axiom:otel_metrics_smoke` emits a one-off OTEL counter. It requires the
  `opentelemetry-metrics-sdk` + `opentelemetry-exporter-otlp-metrics` gems from the Gemfile; without
  them the task skips with an explanatory message.

### Log fields

- Base fields: `ts`, `level`, `request_id`, `job_id`, `app_version`, `user_id`, `ip`, `ua`, `path`,
  `method`, `trace_id`, `span_id`, `_time`
- Payload: arbitrary keys depending on call site
- Emit programmatically via `StructuredLogger.info/warn/error/debug(hash_or_message, extra: ...)`.

### Structured logs vs. OTEL logs

- StructuredLogger pushes curated JSON events (CI, deploys, ops actions, job lifecycle) straight
  into `otel-logs`. Each entry contains high-signal fields and can be enriched with domain-specific
  metadata.
- OTEL logs are part of the OTLP spec, but Axiom already receives our high-value logs via the
  structured channel. We keep OTEL logs disabled to avoid redundant ingest and stay within dataset
  quotas. If we ever need OTEL logs (for automatic log correlation from agents), they can target the
  same `otel-logs` dataset without touching credentials.

### Dataset field limits & map fields

`otel-logs` lives on Axiom’s free tier, which limits each dataset to 256 fields. When we push events
rich in custom attributes we can exceed that limit (recently `otel-logs` rejected four events for
this reason), so incoming data stops being stored until the limit is addressed. The recommended
solution is to regroup high-dimensional or unpredictable data into map fields.

Map fields behave like a JSON object inside one named column, so dozens of attributes can be stored
without adding one schema field per key. They are especially helpful for unpredictable custom
attributes, feature flags, or instrumentation that adds hundreds of keys. Keep in mind that map
fields can be more expensive to query and less compressible when values vary wildly, so prefer
standard flattened fields for stable, low-cardinality data.

#### Runbook: recovering from a field-limit stop

> **Prerequisite:** store the dataset admin (master) key in `credentials[:axiom][:master_key]` or
> `AXIOM_MASTER_KEY` so the helper tasks and API calls below can authenticate.

1. **Identify noisy keys** – Inspect rejection payloads or list the current schema via
   `axiom datasets fields list otel-logs | sort` (requires the Axiom CLI) or
   `bin/rails "axiom:fields:list[otel-logs]"` (uses the new `axiom.master_key`). Note which
   flattened keys pushed the count beyond 256 — common culprits are `attributes.custom.*`, feature
   flags, and dynamic headers. Filter with a prefix using
   `bin/rails "axiom:fields:list[otel-logs,attributes.]"` when you want to focus on one subtree.
2. **Group high-cardinality attributes** – Decide on parent map names (`attributes.custom`,
   `feature_flags`, `headers`, etc.) that can safely contain those dynamic keys. The goal is one
   schema slot per group instead of hundreds of flattened siblings.
3. **Create map fields** – Use the Axiom UI (Datasets → `otel-logs` → Fields → ••• → Create map
   field), the new Rake task (`bin/rails "axiom:fields:create_map_field[attributes.custom]"`), or
   the API:
   ```bash
   curl -X POST https://api.axiom.co/v2/datasets/otel-logs/mapfields \
     -H "Authorization: Bearer ${AXIOM_MASTER_KEY}" \
     -H "Content-Type: application/json" \
     -d '{"name":"attributes.custom"}'
   ```
   Repeat per parent field. Newly ingested events route into these map fields without consuming
   additional schema slots.
4. **Update collectors / StructuredLogger** – Ensure emitters place the dynamic attributes inside
   the chosen parent map before resuming high-volume ingest. For OTEL, arbitrary span attributes
   should live under `attributes.custom`. For other payloads, wrap the key/value blob under the new
   map parent (`feature_flags`, `request.headers`, etc.).
5. **Verify ingest** – Send a handful of test events and run an APL query to confirm nested reads,
   e.g.:
   ```kusto
   ['otel-logs']
   | where ['attributes.custom']['http.protocol'] == 'HTTP/1.1'
   | take 5
   ```
6. **Clean up old schema** – Trim historical time ranges that still contain the oversized flattened
   fields (Datasets → `otel-logs` → Trim) and then Vacuum the dataset (Fields → Vacuum). This frees
   the retired field slots.
7. **Monitor usage** – Keep an eye on Datasets → Fields → Usage or set a weekly alert. Consider
   preemptively moving any other unpredictable attribute groups into map fields and upgrade the plan
   only if your steady-state schema truly requires more than 256 flattened fields.
8. **Ops panel helpers** – The `/ops` dashboard now exposes schema stats, top fan-out parents, and
   buttons for map-field promotion, dataset trim, and vacuum operations (all powered by
   `axiom.master_key`). Prefer these tools for day-to-day maintenance so the workflow stays in one
   place and every action is logged via StructuredLogger.

#### Creating map fields

- **UI** – In Axiom’s dataset view go to More → Create map field, give the fully qualified field
  name (e.g., `attributes.custom`) and save. New data ingested into that field won’t count toward
  the dataset’s field limit.
- **API** – POST to `https://api.axiom.co/v2/datasets/{DATASET_NAME}/mapfields` (replace
  `{DATASET_NAME}` with `otel-logs` or another dataset) using `Authorization: Bearer API_TOKEN` and
  a JSON body such as `{"name":"MAP_FIELD"}`.
- **Vacuuming** – After the collector stops sending flattened fields that you now treat as map
  fields, vacuum the dataset (and trim old rows if needed) so those retired fields stop occupying
  space in the schema.

#### Querying map fields

Access map properties using index notation (`['map_field']['prop']`), dot notation
(`map_field.prop`), or a mix of both. Always quote identifiers that contain spaces, dots, or dashes.
Example:

```kusto
['otel-demo-traces']
| where ['attributes.custom']['http.protocol'] == 'HTTP/1.1'
```

OTEL traces already place SDK-supplied custom attributes in `attributes.custom`, so use
`['attributes.custom']['header.Accept']` to access the `header.Accept` key even though it looks like
nested JSON.

Note: flattened fields such as `['geo.city']` and map-based siblings like `['geo']['city']` are
treatments of different columns in the schema. Be explicit in queries and schema design to avoid
accidentally reading the wrong field.

Release correlation

- Set `APP_VERSION` (preferred) or `GIT_SHA` in the environment to annotate every log with
  `app_version`.
  - Example (Kamal): `APP_VERSION=$(git rev-parse --short HEAD) bin/kamal deploy`

Job correlation

- All ActiveJob runs include `job_id` automatically and log `job_start`, `job_finish`, and
  `job_error` with durations.

Forwarding controls

- Set `AXIOM_TOKEN` in credentials. Logs default to the `otel-logs` dataset, so no extra config is
  required unless you want different dataset names. Override via `AXIOM_DATASET`,
  `AXIOM_TRACES_DATASET`, or `AXIOM_METRICS_DATASET` env vars when needed.
- Forwarding runs automatically in production when the token is present. In other environments, opt
  in with `AXIOM_ENABLED=1`.
- You can force a one-off send with `StructuredLogger.info(..., force_axiom: true)` (used by the
  runtime doctor task).

### CI and Deploy Telemetry

- GitHub Actions emits deployment and CI events to Axiom when `AXIOM_TOKEN` is provided (secret) and
  `AXIOM_DATASET` is set (can be a non-secret Actions variable, defaults to `otel-logs` locally).
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
- Secrets required: `AXIOM_TOKEN`
- Non-secrets (can be Actions variables): `AXIOM_DATASET` (usually `otel-logs`), `AXIOM_BASE_URL`
  (if not US)
- Optional:
  - Email on deploy failure via Resend (`RESEND_API_KEY`, `TO_EMAIL`)

#### Queries / Dashboards

- CI reliability: group by `message` and `repo`, chart success/error counts over time.
- Release quality: filter `deploy_*` events and correlate durations.
- Supply-chain visibility: join `ci_image_built` and `ci_sbom_attested` by `image.digest`.

## Traces & Metrics (OpenTelemetry)

We recommend enabling OTEL for Rails, ActiveRecord, and HTTP clients, exporting to Axiom’s OTEL
endpoint via OTLP/HTTP. Axiom currently ingests OTEL traces (and standard logs) — metrics are
“coming soon” per their docs. We still keep the OTEL metrics exporter wired up so nothing changes
when Axiom flips the switch; until then, metric export attempts simply no-op. Metrics will share the
`otel-traces` dataset by default so we remain within the two-dataset allowance.

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
gem "opentelemetry-metrics-sdk"
gem "opentelemetry-exporter-otlp-metrics"
```

2. Initialize OTEL (traces + metrics):

```ruby
# config/initializers/opentelemetry.rb
require "opentelemetry/sdk"
require "opentelemetry-metrics-sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry-exporter-otlp-metrics"
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
  reader = OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader.new(
    exporter: OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new(
      endpoint: metrics,
      headers: metrics_headers
    ),
    export_interval_millis: (ENV["OTEL_METRICS_EXPORT_INTERVAL_MS"].presence || 60000).to_i
  )
  c.add_metric_reader(reader)
end
```

3. Env vars (override only if you need non-default names):

- `AXIOM_TOKEN`: token with tracing ingest permissions (secret; set in credentials/secrets)
- `AXIOM_DATASET`: structured logs dataset (defaults to `otel-logs` via `AppConfig.axiom`)
- `AXIOM_TRACES_DATASET`: traces dataset (defaults to `otel-traces`)
- `AXIOM_METRICS_DATASET`: optional metrics dataset override; defaults to `AXIOM_TRACES_DATASET`

  > **Plan note:** We deliberately stick to two datasets (`otel-logs` and `otel-traces`) to stay on
  > the free tier. OTEL traces (and future metrics) share `otel-traces`; JSON logs, CI/deploy
  > events, and direct ingest use `otel-logs`.

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
  - Logs dataset: `https://app.axiom.co/${AXIOM_ORG}/datasets/${AXIOM_DATASET}` (defaults to
    `otel-logs`)
  - Traces dataset: `https://app.axiom.co/${AXIOM_ORG}/datasets/${AXIOM_METRICS_DATASET}` (defaults
    to `otel-traces`; doubles as the metrics landing spot once Axiom enables OTEL metrics)
  - Traces UI: `https://app.axiom.co/${AXIOM_ORG}/traces?service=${OTEL_SERVICE_NAME}`

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
