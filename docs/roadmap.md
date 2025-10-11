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

- DB schema for cards; map profile → card fields (stats, tags)
- Base HTML/CSS template (no on-image text from prompts)
- Tests: schema + template rendering smoke tests

PR 08 — Screenshot worker (Puppeteer/Playwright)

- Headless screenshot of card route; output stored with images
- Job wiring + retries; artifacts linked in metadata
- Tests: job unit + golden-dimension checks

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
