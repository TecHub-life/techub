# Observability: Axiom and OpenTelemetry

This guide explains how to wire TecHub logs and traces to Axiom using JSON logs and OpenTelemetry
(OTEL).

## Logs → Axiom

- Current logging is JSON to STDOUT via `config/initializers/structured_logging.rb`.
- If `AXIOM_TOKEN` and `AXIOM_DATASET` are set, logs are also sent to Axiom (best-effort) via
  Faraday.
- Configure:
  - `AXIOM_TOKEN`: Axiom personal or ingest token
  - `AXIOM_DATASET`: target dataset name (logs/events)
  - `AXIOM_METRICS_DATASET`: optional metrics dataset name
- In production, deploy with these env vars to enable forwarding.

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
  `method`
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
