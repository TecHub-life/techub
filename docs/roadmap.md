# Roadmap

## Current state and gaps (explicit)

- The current public profile page UI is not acceptable for product v1; it is an interim view.
- AI text/traits generation is NOT implemented; only heuristic stats/tags exist.
- Directory UX is rudimentary; needs a cards-first browse experience and styling overhaul.
- These items are prioritized in upcoming PRs and considered blockers for a shippable v1.

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

PR 04 — Image storage: S3/GCS (DONE)

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
- Background job (DONE): Solid Queue job runs screenshots asynchronously; artifacts recorded.
- Retries + golden-dimension checks (NEXT)

PR 09 — Profile synthesis service + validators (PENDING)

- `ProfileSynthesisService` (AI text: short/long bios, buffs, traits) — NOT DONE
- Validators and re-ask loop for constraints — NOT DONE
- Persist to model; render AI section on profile page — NOT DONE
- Tests: rule coverage + re-ask loop — NOT DONE

PR 10 — OG image route + share pipeline

- Route that renders a shareable card preview
- Background job to pre-generate OG assets
- Tests: route + job integration

PR 11 — Observability

- Structured logs for provider responses (status, model, tokens)
- Dashboard doc for rate-limit/error monitoring
- Tests: log keys present in service results

PR 12 — Docker Compose validation + healthchecks (DONE)

- Single image runtime: web and jobs run from the same container image
- docker-compose.yml for local proof with services: web, worker
- Health endpoints: `/up`, `/ops/jobs` (where mounted)
- Docs: `docs/ops-runbook.md` covers local Compose and checks
- CI: optional compose-based smoke target (NEXT)

PR 13 — Ownership & limits (My Profiles) (DONE)

- Data model: link `User` ↔ `Profile` ownership (claim + list)
- UI: “My Profiles” page with add/remove
- Policy: enforce per-user cap (default 5)
- Docs: auth-and-ownership, workflow updates

Definition of Done

- Code: Users ↔ Profiles association; policy enforcing per-user cap (default 5); claim/list/remove
  actions.
- UX: “My Profiles” page with add/remove; clear error on cap exceeded.
- Tests: model association + policy; controller actions; cap enforcement.
- Docs: `docs/auth-and-ownership.md` updated with flows and limits.
- Observability: structured logs for claim/removal events.

PR 14 — Eligibility gate in pipeline (DONE)

- Enable `require_profile_eligibility` in the generation pipeline/job
- Surface decline reasons (signals) in UI and JSON
- Docs: eligibility policy + cost control

Definition of Done

- Code: Gate enforced by default in `GeneratePipelineService` (override only via
  `REQUIRE_PROFILE_ELIGIBILITY=0`).
- Behaviour: Failure returns `ServiceResult` with `eligibility` metadata (score, signals).
- Tests: pass/fail paths; gate default-on; override disables.
- Docs: `docs/eligibility-policy.md` (signals, scoring, override) + `docs/user-journey.md`.
- Observability: structured logs include stage marker and reasons.

Definition of Done

- Code: Gate enforced in `GeneratePipelineService` behind `REQUIRE_PROFILE_ELIGIBILITY` flag.
- Failure path: returns `ServiceResult` failure with `eligibility` metadata (score, signals).
- Tests: pass/fail paths; signals covered; flag off bypasses gate.
- Docs: `docs/user-journey.md` and `docs/debugging-guide.md` updated with failure handling.
- Logs/Artifacts: clear stage marker and reasons in structured logs.

PR 15 — Avatar uploads & unified assets

- Upload avatars via Active Storage (DO Spaces) like other assets
- Record avatar `ProfileAssets` rows with public URLs
- Update views to prefer CDN URLs

PR 16 — Full pipeline job orchestration (DONE)

- Add `Profiles::GeneratePipelineJob` (sync → images → synth → screenshots → optimize)
- Retries/backoff and status logging; visible in Mission Control
- Tests: job success/failure paths, idempotence

PR 17 — Billing feature flag (Stripe-ready)

- Introduce `STRIPE_ENABLED` flag and entitlement checks around generation
- Stub billing service/interfaces for later Stripe drop-in
- Docs: configuration and upgrade path

PR 18 — Submit: manual inputs + scraping (DONE)

- Spec: End-to-end documented in `docs/submit-manual-inputs-workflow.md` (start here).
- UX (pending): Extend submit page to accept personal URL + up to 4 GitHub repos.
- DB (scaffolded): `profiles.submitted_scrape_url`; support `repository_type: "submitted"`; new
  `profile_scrapes` table for storage.
- Sync (done): Preserve `submitted` repos during GitHub sync.
- Orchestrator (partial): Services exist; flag-gate pipeline pre-steps; non-fatal failures with
  logging.
- Tests (done): Scraper + record + preservation; add controller + pipeline integration tests when
  wiring UI.

Definition of Done

- Code: Submit controller/form; stores `submitted_scrape_url` and up to 4 repos; pipeline pre-steps
  gated by `SUBMISSION_MANUAL_INPUTS_ENABLED`.
- Services: `IngestSubmittedRepositoriesService` hydrates topics/metadata;
  `RecordSubmittedScrapeService` persists content/links with caps.
- Tests: form validation; services success/failure; pipeline integration with flags on/off.
- Docs: `docs/submit-manual-inputs-workflow.md` finalized; `docs/user-journey.md` updated.
- Observability: logs for ingest/scrape stages; DB records verifiable; size/time caps enforced.

PR 19 — Custom backgrounds & 3x1 banner

- Add upload UI in My Profile settings for `og`, `card`, `simple`, and `3x1` banner
- Store uploads as `ProfileAssets` kinds: `og`, `card`, `simple`, `avatar_3x1`
- Prefer uploaded assets over generated ones in renders
- Roadmap follow-up: optional per-card-type custom assets; background selection UI

Definition of Done

- Code: Controller endpoint to upload/overwrite assets; validation and storage to Spaces when
  enabled
- UX: Settings page shows previews and upload buttons per kind; overwrite semantics are clear
- Docs: `docs/background-selection.md` updated to include `3x1` support and owner uploads
- Observability: structured logs on upload success/failure

PR 20 — Regeneration limits & non-AI re-capture

- Split regeneration into two flows: non-AI re-capture (unlimited) and AI artwork regeneration
  (rate-limited)
- Enforce weekly limit per profile for AI artwork regeneration
- Pipeline accepts `ai: false` to skip AI generation and only re-capture screenshots/optimize
- Settings UI shows availability and next allowed time

Definition of Done

- Code: `Profiles::GeneratePipelineService` supports `ai:` flag; job accepts and forwards `ai`
- Policy: `last_ai_regenerated_at` tracked per profile; allow once per 7 days
- UX: Two buttons in Settings; AI button disabled with explanation until window opens
- Docs: `docs/ops-runbook.md` updated with limits; `docs/user-journey.md` clarifies flows

Milestone — E2E Auth → Submit → Generate status

- See `docs/status-dashboard.md` for authoritative status and links.
- See `docs/user-journey.md` for the end-to-end flow and data ownership.
- See `docs/submit-manual-inputs-workflow.md` for the manual inputs spec.

## Operational policies

- Prompts never request on-image text or logos; traits are non-visual anchors only
- Provider flakiness must not break pipelines: retries + profile fallback path
- All AI calls return `ServiceResult` with rich metadata for auditing

## Backlog

- Eligibility funnel + decline messaging
- Admin dashboard and moderation
- Notifications on completion (Partial: ActionMailer in place; Resend provider wiring pending)
- API endpoints for programmatic card access
- Physical printing pipeline
- Leaderboards/trending, marketplace integrations, mobile client

Raw Profiles deprecation

- Remove public references and links to `/raw_profiles` in UI (landing, examples)
- Keep routes for legacy/testing temporarily; restrict access behind admin flag if needed
- Move raw JSON/profile refresh to owner-only tools within `My Profiles` settings
- Add a button to refresh raw profile data in settings; show last synced timestamp
- DoD: UI has no raw links; settings include refresh; docs updated

## Next Up (sequenced TODOs)

PR 19 — Directory Listing (browse)

- Page: `/directory` lists recent successful profiles (`last_pipeline_status = 'success'`),
  paginated
- Includes avatar, name/handle, and links to profile and OG/card assets
- Sorting: most recent first; optional search stub
- DoD: tests for listing ordering; view renders with seed data

PR 20 — OG Image Route + Pre‑Gen

- Route: `/og/:login` returns the generated JPEG (302 to CDN URL when uploaded)
- If missing, respond 202 + enqueue `Profiles::GeneratePipelineJob` (idempotent) and return JSON
- Hook: on submission and on successful sync, pre‑enqueue OG/card screenshot generation
- DoD: controller/unit tests; integration test for 202→ready path

PR 21 — Retry/Backoff Metrics

- Enrich `retry_on` flows with attempt/backoff in structured logs for pipeline + screenshot jobs
- Surface attempts/durations on profile page and in Mission Control notes
- DoD: log keys present; sample rendered in UI

PR 22 — Mission Control Polish

- Add per‑profile pipeline stage/status (sync, gen, synth, screenshots, optimize)
- Show last error, attempts, and asset links
- DoD: basic read‑only view; no write actions required

PR 23 — Eligibility Decline UX

- Present score and top signals on failure paths (profile + submit flows)
- Link to docs for improvement tips
- DoD: UI and JSON include signals when gated

PR 24 — Image Pipeline Finalization (DONE)

- Default screenshots to progressive JPEG (q=85); keep PNG for transparency
- Heavy optimization in background with upload + metrics; threshold via `IMAGE_OPT_BG_THRESHOLD`
- Views resilient to `.jpg/.png`; profile OG tags prefer generated JPEG

PR 26 — Background Selection (owner UI + storage)

- Storage plan: persist multiple background candidates per profile (16x9 focus) as independent rows
  (new table `profile_backgrounds`) with fields: `profile_id`, `kind` (`bg_16x9`, `bg_card`, etc.),
  `local_path`, `public_url`, `provider`, `sha256`, `generated_at`, `selected`.
- Generation: keep saving current single canonical assets via `ProfileAssets` for backwards‑compat;
  additionally write each new candidate to `profile_backgrounds` (and DO Spaces when enabled).
- UI: “Choose Background” in Profile Settings lists recent backgrounds, allows selecting one as
  active; screenshots use the selected one if present, otherwise latest.
- Cleanup: optional retention policy (keep last N=5 per kind), recurring prune job.
- DoD: table + model; write path from generation; settings page list/select; screenshots prefer
  selected; docs updated.

PR 27 — Theme & Color Customization (owner UI)

- Extend Profile Settings to allow per‑variant color palettes and text color selections (simple,
  card, og)
- Persist selections alongside existing `profile_cards.theme` / `profile_cards.style_profile` (or a
  small JSON column for `theme_options`)
- Templates read owner selections to render consistent previews/screenshots
- DoD: settings form + persistence; previews reflect chosen colors; docs updated
  (`docs/asset-guidelines.md`)

PR 28 — Public Profile Page (Product v1) (PENDING)

- Replace current `profiles/:username` view with product page (cards-first)
- Pull from `ProfileCard`, `ProfileAssets`, OG/card/simple screenshots; show generated artifacts
- CTAs: View/copy OG URL, Share, View card variants; enqueue generation when missing (202 UI)
- SEO: OG/Twitter tags use generated images; canonical URL
- Fallbacks: skeleton/loading states, eligibility messages when gated
- Tests: controller/view integration; artifacts presence/absence; share links
- DoD: page is the primary “product” view; no raw data dump here
- Status: current page is interim; AI text + final layout pending

PR 29 — Header/navigation cleanup

- Single source of truth for account actions; remove duplicate “My Profiles”
- When signed in: one My Profiles entry + Sign Out; when signed out: Sign In
- Optional: user avatar chip linking to GitHub profile
- Tests: nav renders correctly for signed in/out states

PR 30 — Raw profile tooling (owner-only)

- Move raw JSON/profile refresh to `My Profiles → Settings` (owner only)
- Add “Refresh from GitHub” button + last synced timestamp
- Remove public links to `/raw_profiles`; keep routes flagged for admin/tests only
- Tests: settings renders refresh; action queues sync and updates timestamp

PR 25 — Prompt Context Enrichment (DONE)

- Extend `profile_context` with: followers band, activity intensity (90d), tenure (years), 1–2
  dominant topics (owned/org only), hireable flag.
- Fold into AvatarPromptService “Profile traits” line with strict length caps; no on-image
  text/logos.
- DoD: traits appear in prompts metadata; implemented with owner/org filtering for topics.
