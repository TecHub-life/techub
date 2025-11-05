---
version: '1.9'
updated_at_local: '2025/11/05 19:47 (Australia/Melbourne)'
updated_at_utc: '2025/11/05 08:47 (UTC)'
captain: 'Dean Lofts'
---

# Loftwah’s Coding Philosophy v1.9

**Dean Lofts (@loftwah)** Practical, testable, observable, and maintainable.

> “I don’t want magic. I want to see every moving part, be able to turn it off, and still boot the
> thing.” This is how I build **Rails 8** apps with **SolidQueue** (no Redis), **SQLite** (local +
> production), and **Mission Control** for ops.  
> It’s for a **GitHub profile generator**: users sign in via GitHub, submit up to 5 profiles,
> triggering an async pipeline to pull data, generate structured output with Gemini, render Rails
> view screenshots in social media sizes, and email updates—all tracked in an ops panel. It covers:

- Runtime structure
- Pipelines, degraded states, debugging
- Observability
- UI polish
- Secrets and deployment
- Local/production parity and smoke
- Testing levels
- Feature flags and kill switches
- Core integrations
- **Frigate command model**
- **Precedence-based comms & alerting**
- **OpsContext for unified events**
- **Authority as code, rank & department** Goal: **repeatable delivery with zero chaos** — no Redis,
  no Postgres, no excuses.
  > **TL;DR:** Ship services with visible spine (`steps` → `run` → `describe`), fail gracefully
  > (ok/degraded/failed), prove reality (doctor, smoke, parity). Code owns behaviour, secrets
  > encrypted at rest/decrypted at boot, every decision observable (OpsContext with precedence).
  > CORS, CI, tags, flags are enforced contracts. If panel shows it, script can do it. **Zero chaos.
  > No Redis. No Postgres.** **Glossary:**
- **Service**: Orchestrator with `steps`, `run`, `describe`.
- **Mechanism**: Single unit of work in a step.
- **Doctor**: Script proving dependency works.
- **Smoke**: E2E probe on production-parity stack.
- **OpsContext**: Canonical event payload.
- **Precedence**: FLASH, IMMEDIATE, PRIORITY, ROUTINE.
- **Ship**: Deployable app following doctrine.
- **Degraded**: Operation used fallback but continued.
- **Failed**: Operation halted; caller stops or pages.
  > **Summary:** Reproducible way to build/operate Rails apps where services are observable,
  > testable, reversible—replacing vibes with contracts so any ship can be debugged/audited/restored
  > by logbook readers. **Sections:** Env & Secrets · Mechanisms & Pipelines · Observability ·
  > Frigate Model

---

## Executive summary

Doctrine for building/operating **Rails 8 + SolidQueue + SQLite** apps so every ship is debuggable,
auditable, recoverable mid-incident by OpsContext readers. Aligns runtime, CI, comms, authority
under enforceable playbook.

## 0. Document metadata

- Version: v1.9
- Owner: Dean Lofts (@loftwah)
- Language: Australian English
- Runtime: **Rails 8**, **SolidQueue (no Redis)**, **SQLite (local + prod)**, **Mission Control**
- Policy: Document is truth. Runtime, ops panel, CI, alerting, authority MUST match. If production
  drifts, non-compliant until updated by CAPTAIN/XO.

## 0.1 Code policy

Examples in Ruby (Rails services/workers). Stack-agnostic pseudocode for concepts.

## 0.2 Adoption checklist

New repo fleet-ready:

- `loftwah-philosophy.md` + `.cursorrules`.
- `ops/env-allowlist.md`, `config/ops_authorised.yml`, `ops/logs/`.
- `app/observability/ops_context.rb`, `app/services/telemetry_service.rb`,
  `ops/policy/schemas/ops-context.schema.json`.
- `bin/feature`, `ops/feature-flags.json`.
- `docs/templates/comms/incident.txt`, doctors, smokes, CI scripts (`bin/check-authority`). Ship
  these, CI fails on drift.

---

## Zero-to-fleet (8 steps)

1. Add `loftwah-philosophy.md` + `.cursorrules`.
2. Add `app/observability/ops_context.rb`, `config/ops_env.rb`, `app/services/telemetry_service.rb`.
3. Add `ops/policy/schemas/ops-context.schema.json` + test.
4. Add doctors: `bin/doctor-*` for vendors.
5. Add smoke: `bin/smoke-local` hitting service.run.
6. CI: lint → tests → smoke → OPA.
7. Add feature flags (`config/features.rb`) + expiry checker.
8. Ship CORS + probes; verify OpsContext in Mission Control/Axiom.

---

## 1. Environment, config, secrets

### 1.1 Env vars: minimal surface

Env for identity/boot **only**. Allowed:

```
RAILS_ENV
WEB_HOSTS
JOB_HOSTS
DATABASE_URL # SQLite only (sqlite3:./data/app.sqlite3)
KAMAL_REGISTRY_PASSWORD
RAILS_MASTER_KEY
APP_URL
APP_NAME
# CI/deploy only
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

> **No Redis. No Postgres. No excuses.** New vars documented in `ops/env-allowlist.md`; undeclared
> fail CI.

### 1.2 Code over config

Behaviour in code:

```ruby
# config/application.rb
module Config
  class << self
    def app
      raw_env = ENV["RAILS_ENV"] || "development"
      env = raw_env.downcase == "production" ? "production" : "development"
      {
        name: "github-profile-gen",
        env: env,
        url: ENV["APP_URL"] || "https://techub.life",
        hosts: (ENV["WEB_HOSTS"] || "https://techub.life").split(","),
      }
    end
    def db
      {
        url: ENV["DATABASE_URL"] || "sqlite3:./data/app.sqlite3",
        # No SSL — SQLite
      }
    end
    def features
      {
        gemini_enabled: true,
        max_profiles: 5,
      }
    end
  end
end
```

### 1.3 Secrets: repo-encrypted default

`ops/secrets/app.enc.yaml` decrypts at boot with `MASTER_KEY`. Alternatives (1Password, SSM)
preserve interface.

```ruby
# lib/secrets_backend.rb
module SecretsBackend
  def self.load
    backend = ENV["SECRET_BACKEND"] || "repo"
    case backend
    when "repo"
      YAML.load(ActiveSupport::EncryptedFile.new(
        content_path: "ops/secrets/app.enc.yaml",
        key_path: "ops/master.key"
      ).read)
    end
  end
end
SECRETS = SecretsBackend.load
```

### 1.4 Never in repo

Long-lived creds (AWS root, GitHub god tokens) in 1Password.

### 1.5 AWS auth

Prefer IAM roles; static keys for deploy only.

## 1.6 Tagging

Required tags: | Key | Example | |-----|---------| | Project | github-profiles | | Environment |
production | | Owner | loftwah | | Service | profile-gen | | ExpiryDate | 2026/06/30 (dev only) |
Enforced in Terraform/CI with OPA.

### 1.7 CORS & probes

Explicit allowlist; log decisions. Probes from providers prove origins.

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Config.app[:hosts]
    resource "*", headers: :any, methods: [:get, :post, :put, :delete, :options], credentials: true
  end
end
```

### 1.8 Backups & rotation

## Nightly SQLite dump to S3. Weekly restore drill. Rotate keys every 90d; CI blocks overdue.

## 2. Mechanisms, services, pipelines

### 2.1 Result pattern

```ruby
# lib/result.rb
module Result
  def self.ok(value) = { ok: true, value: value }
  def self.err(error) = { ok: false, error: error }
end
```

### 2.2 Service layout

```ruby
# app/services/profile_generation_service.rb
class ProfileGenerationService
  STEPS = %i[pull_github_data generate_gemini_output render_screenshots update_profile send_email].freeze
  def self.describe = STEPS.dup
  def run(github_username:, user:)
    ctx = { username: github_username, user: user }
    degraded = []
    STEPS.each do |step|
      result = send(step, ctx)
      return { status: "failed", failed_at: step, degraded: degraded, **result.slice(:error, :attempts, :next_step) } if result[:status] == "failed"
      degraded << { step: step, error: result[:error] } if result[:status] == "degraded"
      ctx.merge!(result[:value]) if result[:value].is_a?(Hash)
    end
    { status: "ok", degraded: degraded, context: ctx }
  end
  def pull_github_data(ctx)
    # Octokit fetch; retry 3x
  end
  def generate_gemini_output(ctx)
    # Gemini structured output; fallback on fail
  end
  def render_screenshots(ctx)
    # Rails view → screenshot in OG, Twitter, 1x1, 16:9
  end
  def update_profile(ctx)
    # Save to SQLite; enforce 5/user
  end
  def send_email(ctx)
    # Resend update; degrade if fail
  end
end
```

Async via **SolidQueue** (no Redis):

```ruby
# app/jobs/profile_generation_job.rb
class ProfileGenerationJob < ApplicationJob
  queue_as :default
  def perform(github_username, user)
    ProfileGenerationService.new.run(github_username: github_username, user: user)
  end
end
```

### 2.3 Debug tooling

`bin/pipeline-debug <step> <username> [context.json]` runs single step.

### 2.4 Degraded states

StepResult status: ok/degraded/failed. Retry with backoff. Schema enforced with tests.

### 2.5 Service contract

## Every service: `run`, `steps`, `describe`. Pipeline tracks degraded, stops on failed.

## 3. UI Quality

## Ship with loading/empty/error states. Consistent primitives. Support mobile/tablet/desktop. Include favicon, OG/Twitter cards.

## 4. Doctors & Ops Panel

## `bin/doctor-github`, `bin/doctor-gemini` prove integrations. **Mission Control** shows: last checks, logs, flags, job status (SolidQueue).

## 5. Observability

### 5.1 OpsContext

```ruby
# app/observability/ops_context.rb
module OpsContext
  PRECEDENCE = %w[FLASH IMMEDIATE PRIORITY ROUTINE].freeze
  def self.build(partial)
    now = Time.now
    {
      ts_local: now.in_time_zone("Australia/Melbourne").strftime("%Y/%m/%d %H:%M (Australia/Melbourne)"),
      ts_utc: now.utc.strftime("%Y/%m/%d %H:%M (UTC)"),
      app: Config.app[:name],
      environment: Config.app[:env],
      precedence: "ROUTINE",
      event: "unspecified",
      actor: { human: "system", role: "MIDSHIPMAN" },
      **partial
    }
  end
end
```

Schema enforced.

### 5.2 Telemetry

Emit to Axiom/**Mission Control**. Fallback to local logs on fail.

### 5.3 Notifications

## Alert on precedence via Resend/Slack.

## 6. Parity & Smoke

## Docker Compose for prod-like local (**SQLite**, **SolidQueue**). Smoke: auth, submit profile, queue job, check pipeline.

## 7. Testing

## 50% mechanisms, 30% services, 20% E2E. Bias E2E for GitHub/Gemini flows.

## 8. CI, Release

## Local CI mirrors remote. Gated prod deploy with approval, smoke, notify.

## 9. Flags

## Typed, with owner/reason/expiry. CI blocks expired.

## 10. Integrations

### 10.1 GitHub

Purpose: auth, pull profiles (up to 5/user). Doctor: GET /user. Degrade: cached data.

### 10.2 Gemini

Purpose: structured output for cool profiles. Doctor: trivial generate. Degrade: basic summary.

### 10.3 Resend

Purpose: emails during pipeline. Doctor: send test. Degrade: log only.

### 10.4 Axiom/Mission Control

## Purpose: observability. Doctor: ingest test. Degrade: local buffer.

## 11. SEO Assets

## Favicon, OG cards mandatory.

## 12. Naming

## Lowercase-hyphen files.

## 13. Migrations

## Reversible; CI checks. Flags for risky.

## 14. Anti-patterns

## No zombie flags, scattered secrets, untested UI states, irreversible migrations, **Redis**, **Postgres**.

## 15. Frigate Model

## App = ship. Departments: Engineering (SolidQueue/SQLite), AI (Gemini), Comms (Resend). Ranks in `ops_authorised.yml`. Precedence for events. Ops panel tabs: Status, Logs, Authority.

## 16. Ship Readiness

## Must have doctors, smoke, OpsContext, degradation policy.

## 17. Readiness Checklist

All integrations/doctors/smoke/parity required for fleet.

### 17.1 First 15 min runbook

## Doctors, smoke, flags, notify.

## 18. Status

- Version: v1.9
- Owner: Dean Lofts (@loftwah)
- Living document: update on reality changes.
