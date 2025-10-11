# Roadmap

## Shipped (baseline)

- GitHub auth + profile ingestion (repos, languages, orgs, README)
- Rails 8 + SQLite + Solid Queue + Kamal baseline ready
- Gemini provider parity (AI Studio + Vertex) for text, vision, image gen
- Verify tasks for prompts/images/stories (both providers)
- Robust parsing + retries (fenced/trailing JSON, MAX_TOKENS handling)
- CI hygiene (push: main, PR: all branches) with concurrency cancel
- Profile-backed prompt fallback when avatar description is weak
- Provider-separated image outputs in `public/generated/<login>` with suffix

## PR Plan (actionable, bite-sized)

PR 01 — Description quality spec + telemetry (DONE)

- Define weak/fragmentary rules (blank, "{", < length threshold)
- Emit metadata: finish_reason, attempts, fallback_used, provider
- Tests cover noisy/fenced/fragment JSON

PR 02 — Profile traits in prompts (DONE)

- Add single “Profile traits (no text/logos)” line (capped, non-visual)
- Keep composition/style unchanged; behind include_profile_traits flag
- Tests assert traits appear/cap, and don’t leak into composition/style

PR 03 — Verify artifacts and UX (DONE)

- Save prompts + metadata JSON per provider under `public/generated/<login>/meta`
- Verify tasks print exact inputs used; add `--verbose` toggle
- Docs updated: how to compare provider outputs and artifacts

PR 04 — Image storage: S3/GCS

- Add storage adapter (env-driven), uploader, and public URL helpers
- Fallback to local if creds absent; docs for credentials and paths
- Tests: uploader unit + integration (stubbed)

PR 05 — Post-processing job (ImageMagick)

- Optimize, strip metadata, and size variants after generation
- Solid Queue job; idempotent; recorded in metadata
- Tests: job unit + verify idempotence

PR 06 — Mission Control (jobs UI)

- Views for Solid Queue queues/jobs; basic filtering
- Health endpoints and links from README
- Docs: operations runbook

PR 07 — Card schema + template skeleton

- DB schema for cards; map profile → card fields (stats, tags) (DONE)
- Base HTML/CSS template (no on-image text from prompts) (DONE)
- SynthesizeCardService to compute attributes from signals (DONE)
- Rake task to persist cards (DONE)
- Tests: service unit + controller views (DONE)

PR 08 — Screenshot worker (Puppeteer/Playwright)

- CLI + service (DONE): `script/screenshot.js` + `Screenshots::CaptureCardService` +
  `rake screenshots:capture` capture fixed-size views to PNG.
- Routes + views (DONE): `/cards/:login/(og|card|simple)` with 1200x630 and 1280x720 frames; use
  generated art when available.
- Background job + retries (NEXT): Solid Queue job to run screenshots asynchronously; link artifacts
  in metadata.
- Tests: service unit (DONE) + golden-dimension checks (NEXT)

PR 09 — Profile synthesis service + validators

- `ProfileSynthesisService` for structured card data (title, tags, traits)
- Validators and re-ask loop for violations
- Tests: rule coverage + re-ask loop

PR 10 — OG image route + share pipeline

- Route that renders a shareable card preview
- Background job to pre-generate OG assets
- Tests: route + job integration

PR 11 — Observability

- Structured logs for provider responses (status, model, tokens)
- Dashboard doc for rate-limit/error monitoring
- Tests: log keys present in service results

PR 12 — Docker Compose validation + healthchecks

- Single image runtime: web and jobs run from the same container image
- docker-compose.yml for local proof with services: web, worker, db
- Healthchecks: Rails app, Solid Queue, Chromium/Puppeteer readiness
- Docs: how to run locally via Compose and verify health
- CI: optional compose-based smoke test target

PR 13 — Ownership & limits (My Profiles)

- Data model: link `User` ↔ `Profile` ownership (claim + list)
- UI: “My Profiles” page with add/remove
- Policy: enforce per-user cap (default 5)
- Docs: auth-and-ownership, workflow updates

PR 14 — Eligibility gate in pipeline

- Enable `require_profile_eligibility` in the generation pipeline/job
- Surface decline reasons (signals) in UI and JSON
- Docs: eligibility policy + cost control

PR 15 — Avatar uploads & unified assets

- Upload avatars via Active Storage (DO Spaces) like other assets
- Record avatar `ProfileAssets` rows with public URLs
- Update views to prefer CDN URLs

PR 16 — Full pipeline job orchestration

- Add `Profiles::GeneratePipelineJob` (sync → images → synth → screenshots → optimize)
- Retries/backoff and status logging; visible in Mission Control
- Tests: job success/failure paths, idempotence

PR 17 — Billing feature flag (Stripe-ready)

- Introduce `STRIPE_ENABLED` flag and entitlement checks around generation
- Stub billing service/interfaces for later Stripe drop-in
- Docs: configuration and upgrade path

## Operational policies

- Prompts never request on-image text or logos; traits are non-visual anchors only
- Provider flakiness must not break pipelines: retries + profile fallback path
- All AI calls return `ServiceResult` with rich metadata for auditing

## Backlog

- Eligibility funnel + decline messaging
- Admin dashboard and moderation
- Notifications (Resend) on completion
- API endpoints for programmatic card access
- Physical printing pipeline
- Leaderboards/trending, marketplace integrations, mobile client
