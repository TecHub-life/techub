## TecHub AppSec, Ops, and Observability Plan

This document captures our application security posture, operational practices, observability with
Axiom, leaderboard plans, and background job scheduling with Solid Queue. It separates people
responsibilities from software automation, and emphasizes a shift-left (and shift-everywhere)
approach.

### AppSec Posture

- **Dependency security (software)**
  - Dependabot: automatic PRs for vulnerable/outdated Ruby, JS packages. Merge cadence: weekly;
    hotfix immediately for critical advisories.
  - CodeQL: GitHub code scanning for Ruby/JS queries on PR and default branch; treat new alerts as
    blocking for security-sensitive areas.
  - CI gates: `bundle audit` and `npm audit --audit-level=high` can be added as non-blocking
    reports; promote to blocking if signal/noise is acceptable.

- **Static analysis (software)**
  - Ruby: Brakeman runs in CI non-interactively with
    `bundle exec brakeman -q -w2 --no-exit-on-warn`.
    - Non-interactive: our `bin/brakeman` disables `--ensure-latest` in CI to avoid prompts.
    - Advisory by default: CI does not fail on warnings; treat the job as signal for PR discussion.
    - Strict option (recommended for security-sensitive work): run a separate job with
      `bundle exec brakeman -q --exit-on-warn` and a baseline/waiver file, or rerun locally.
  - JS/CSS: Prettier runs in CI; add `eslint`/`stylelint` later if needed.

- **Build and supply chain (software)**
  - Reproducible builds: pin base images and OS packages in `Dockerfile`; avoid `latest` tags.
    Prefer distroless/minimal images for runtime.
  - SBOM: generate CycloneDX (`cyclonedx-gem` and `cyclonedx-npm`) during CI; archive artifacts with
    releases.
  - Image scanning: run Trivy/Grype on built images in CI; fail on criticals with allowlist for
    known non-exploitable CVEs.

- **Secrets and credentials (software + people)**
  - Store production secrets in Rails encrypted credentials or environment variables provisioned by
    deploy; never in repo.
  - Rotate tokens regularly; enforce read-only/scoped tokens (GitHub, Axiom). Use per-environment
    least privilege.
  - Review access quarterly (people), revoke unused accounts, enable 2FA on GitHub and cloud
    providers.

- **Runtime hardening (software)**
  - Rails: secure headers, HTTPS-only cookies, CSRF enabled, parameter filtering, rate limiting for
    public endpoints.
  - Content security policy: restrict script/img/font sources, disallow inline where possible.
  - Uploads: validate content-types, size limits, and use background processing. Sanitize image
    metadata where feasible.

- **Network and deployment (people + software)**
  - Kamal deployments over SSH keys to a hardened server.
  - Firewall: default-deny inbound; allow 80/443 via reverse proxy. Restrict SSH to admin IPs or
    Tailscale subnets.
  - Tailscale (plan): expose admin/ops endpoints and SSH only on the tailnet. Public internet only
    sees 80/443.
  - Fail2ban/SSH hardening, unattended upgrades, time-based auto-reboots for kernel patches as
    needed.

- **Application-level controls (software)**
  - Input validation and strong parameter whitelisting in controllers.
  - Authorization checks for any state-changing operation; log and alert on authorization failures.
  - Structured audit logs for sensitive actions.

- **Incident readiness (people + software)**
  - Playbooks in `docs/ops-runbook.md` and `docs/ops-troubleshooting.md` for rollbacks, hotfixes,
    and data protection.
  - Backups: schedule and test restore procedures; document RPO/RTO.
  - Post-incident review template; track follow-ups.

### Dockerfile and maintenance

- Base image: prefer `ruby:*-slim` for build and a minimal runtime (e.g., distroless or slim) with
  multi-stage builds.
- Pin versions for OS packages and gems; use `bundle config set deployment true` and
  `bundle lock --add-platform` for target platforms.
- Non-root user in the final stage; read-only filesystem where possible; explicit writable dirs for
  logs/tmp.
- Healthcheck endpoint and container `HEALTHCHECK` instruction.
- Regular image rebuilds (weekly) even without app changes to pull patched base layers.

### Shift Left and Shift Everywhere

- Pre-commit: RuboCop/Prettier; optional Brakeman and `erb-lint` locally.
- PR level: CodeQL, tests, linters, Trivy/Grype image scan, SBOM generation.
- Deploy level: Smoke tests, database migrations with safety checks, feature flags for risky
  changes.
- Runtime: Axiom logs/metrics/traces; SLOs and alerting; continuous vulnerability scanning of images
  and host.

Responsibilities

- People:
  - Review security PRs, plan rotations, approve firewall/Tailscale ACL changes, run incident
    playbooks.
  - Curate allowlists for scanners, tune CodeQL queries, triage alerts.
- Software:
  - Dependabot, CodeQL, CI gates, image scanners, auto-roll app nodes, recurring jobs for
    maintenance tasks.

### Observability and Axiom

- Logs: JSON logs shipped to Axiom when `AXIOM_TOKEN`/`AXIOM_DATASET` provided; see
  `docs/observability/axiom-opentelemetry.md`.
- Traces: enable OpenTelemetry SDK and exporter (see doc); sample rates configurable via env.
- Metrics: derive from logs and traces; consider rack/request latency, job queue latency, generation
  failures, cache hit rate.
- Interesting profile/GitHub data to collect for Axiom (privacy-scrubbed and aggregated):
  - Profile tenure, followers band, activity level buckets, languages top-N, repository topics
    frequency.
  - AI generation outcomes: prompts present/missing, provider used, success/failure, durations,
    image sizes.
  - Pipeline stages timings and statuses, screenshot capture durations, upload success rates.
  - Leaderboard aggregates (see below) emitted periodically for dashboards.

### Leaderboard Plan

- Purpose: rank profiles by relevant signals to TecHub (not popularity alone).
- Candidate leaderboards (dropdown + date range):
  - Most Improved: delta in activity or repo updates over selected window.
  - Polyglot Score: diversity index of languages used recently.
  - Community Impact: weighted sum of PRs/issues across repos with topic filters.
  - Creator Momentum: recent README changes + release cadence + stars gained normalized by baseline.
- Implementation notes:
  - Precompute aggregates nightly via recurring jobs; store in a small `leaderboards` table keyed by
    type/date-range.
  - API/View: default to “Most Improved (30d)”; allow dropdown of types and date presets
    (7d/30d/90d/all).
  - Fairness: normalize by repo age and baseline activity to avoid giant-project bias; guard against
    gaming.

### Background Jobs and Scheduling (Solid Queue)

- Backend: Solid Queue (see `db/queue_schema.rb`), CLI entrypoint `bin/jobs`.
- Recurring: configured in `config/recurring.yml` (e.g., refreshing tags/stale profiles, queue
  cleanup).
- Operational guidance:
  - Start workers with `bin/jobs` under a process supervisor (systemd or Kamal service).
  - Use multiple queues (e.g., default, screenshots, uploads) with concurrency keys to avoid
    stampedes on a single profile.
  - Emit structured logs for every stage; measure queue latency and job durations; page if
    thresholds exceeded.
- Candidate recurring tasks:
  - Sync stale profiles, update language/topic aggregates, rebuild leaderboards, purge finished
    queue items, rotate temp files.

### Roadmap and Gaps

- Tailscale rollout (admin-only endpoints, SSH, database access) with ACLs; document tailnet DNS and
  hostnames.
- Add Trivy/Grype scanning step in CI pipeline.
- Add Brakeman static analysis and `bundle audit` as advisory CI jobs.
- Implement OTEL by default in production with Axiom OTLP endpoint.
- Implement leaderboards storage and API, plus UI dropdown and date range controls.
- Define PII policy for logs/traces/metrics; scrub or hash identifiers where not needed.

### References

- `docs/observability/axiom-opentelemetry.md`
- `docs/ops-runbook.md`, `docs/ops-admin.md`, `docs/ops-troubleshooting.md`
- `config/recurring.yml`, `bin/jobs`, `db/queue_schema.rb`
