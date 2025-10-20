# Roadmap

## Definitions and Policies (Authoritative)

- Avatar AI art (what): AI‑generated 1×1 portrait variants intended ONLY for avatar circles in
  cards/social views. User chooses: GitHub avatar OR one of AI 1×1 variants.
- Supporting AI art (what): AI‑generated background artwork used behind card/social compositions.
  Targeted aspect ratios: 16×9 (primary), 9×16 (portrait), 3×1 (header). These are BACKGROUNDS only,
  never avatars.
- 3×1 policy: Direct 3×1 AI is flaky; prefer composing banner/header via our `banner`/platform views
  using 16×9 with crop/zoom; 3×1 AI may be generated optionally but is never the only source.
- Upload policy: User uploads are disabled by default (no public UI). Admin/ops may override for
  emergencies.
- Non‑mixing: Avatars come only from GitHub avatar or AI 1×1. Backgrounds come only from supporting
  AI art or admin override. No resizing shortcuts across domains.
- Staleness + regeneration: Per‑target settings (avatar/background/crop) track updated_at. If newer
  than last capture, UI marks “stale” and queues recapture on action.

## End‑to‑End User Flow (Owner)

1. Sign in with GitHub and submit profile (e.g., `loftwah`).
2. Pipeline runs (sync → AI traits/images → screenshots). On success:
   - Profile page → Cards tab shows `og`, `card`, `simple`, `banner` and per‑platform social images.
   - Settings → Social Assets shows all targets with previews and Generate button.
3. Settings: For each target, choose avatar (GitHub or AI 1×1) and background (AI 16×9/9×16/3×1 or
   default). Safe defaults apply.
4. If settings change, targets are marked stale; “Generate” triggers screenshot job and (optional)
   upload; previews update on completion.

## Immediate Roadmap (Do Not Skip)

Owner: \***\*\_\_\*\*** Updated: \***\*\_\_\*\***

- [ ] Social assets: derive ONLY from dedicated card views/screenshots
  - Source of truth:
    - x_header, fb_cover, linkedin_cover → `cards/:login/banner` screenshot view
    - x_feed, youtube_cover, og_1200x630 → `cards/:login/og` screenshot view
    - profile squares (x/ig/fb/linkedin) → dedicated `cards/:login/avatar_square` view with selected
      avatar
    - ig_portrait → dedicated `cards/:login/portrait` view with selected avatar
  - Remove `src_kind` from social generation; deprecate resizing service in favor of card views per
    target
  - No cross‑mixing: AI art is not used for card/banners; screenshots are not used as avatars
  - DoD: per‑target views exist and are captured by screenshot job; settings lets user select
    avatar/background per target; tests enforce mapping

- [ ] AI character styles/variants for avatars (no service changes)
  - Generate multiple 1×1 variants per profile using distinct, reusable style recipes (e.g., robot,
    retro game, alien, synthwave, painterly). Use existing image generator only; do not modify the
    service.
  - Record variants in asset library; surface choices in Settings for avatar selection.
  - DoD: at least 3 style buckets per profile; selectable in Settings; shows in all card/social
    views using avatar circle.

- [ ] Motifs: system artwork (archetypes and spirit animals)
  - Boot ensure: on app start, ensure motif images exist for `MOTIFS_THEME` (default `core`);
    generate only missing.
  - Rake: `rake motifs:generate[THEME,ENSURE_ONLY]` and `rake motifs:ensure[THEME]` for manual runs.
  - Storage: global library under `public/library/(archetypes|spirit_animals)/<theme>/` with
    `*-<variant>.jpg`.
  - Decoupling: system motifs are global; not tied to profiles or avatar assets.
  - Admin: later, ops panel to add new themes and (re)generate subsets; buttons greyed when present.
  - DoD: boot-time ensure works; rake tasks generate assets; docs updated.
  - Lore: generate `*.json` per motif with `short_lore` and `long_lore` via Gemini; fallback to
    catalog description.
  - Variants: default to 1x1 and 16x9 (drop 3x1); update tests accordingly.
  - Tests: add unit tests for lore JSON shape and presence; verify ensure/generate flows; CI task
    lists library counts.

- [ ] Axiom + OTEL
  - Logs: verify dataset ingest via ops smoke action
  - Traces: add OTEL gems + initializer exporting to Axiom OTLP
  - DoD: smoke visible in Axiom; traces present for web requests and jobs

- [ ] Docs/OpenAPI reliability
  - Remove CDN for ReDoc and Font Awesome; use vendored/gem assets
  - Dark/light theme parity; images render via safe rewrite
  - DoD: page functional offline; consistent styling

- [ ] Directory UX
  - Prominent link: “Motifs & Lore” from directory filters header
  - Tags: chip‑based multi‑select using existing autocomplete
  - DoD: link placement approved; multi‑select works

- [ ] Guardrails (don’t break generation/storage again)
  - Contract tests: `AvatarImageSuiteService`, `ActiveStorageUploadService`
  - Pipeline step tests (mock providers) assert outputs are written/recorded
  - Feature flags to isolate AI from screenshots
  - DoD: tests in CI; flags documented

- [ ] Dimension telemetry (under observability)
  - Record actual width/height for generated AI images and screenshots in logs/metadata to confirm
    common AR results (often 1×1) and inform composition defaults.
  - DoD: log fields present; simple report in ops.

Non‑mixing policy (must follow)

- AI assets: only `avatar_*` variants and motif portraits
- Card assets: only from card routes (`og`, `card`, `simple`, `banner`) via screenshots
- Social assets: post‑processed from their designated source classes above
- Violations must be rejected in PR review

Implementation constraints (no surprises)

- Do not modify AI image generation service or storage upload service for this work.
- Remove user uploads UI for images (admin-only if retained). Build views around likely 1×1 inputs;
  rely on object-cover in views, not per-user crop/zoom controls.
- Ship as cohesive changes to views, screenshot variants, and settings only.

## Current state and gaps (explicit)

- Public profile page UI remains interim; Product v1 layout still pending (cards‑first).
- AI text/traits generation implemented with validators and fallback; re‑ask loop added; tests
  pending.
- Directory UX exists and is functional; filters and styling are improving but not final.

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

PR 09 — Profile synthesis service + validators (PARTIAL)

- `ProfileSynthesisService` (AI text: short/long bios, buffs, traits) — DONE
- Validators and re‑ask loop for constraints — DONE (one strict re‑ask; fallbacks); tests pending
- Persist to model; render AI section on profile page — DONE
- Tests: rule coverage + re‑ask loop — PENDING

PR 10 — OG image route + share pipeline (DONE)

- Route `/og/:login` returns generated image or 202 with enqueue
- Integrated with pipeline for generation; artifacts saved
- Tests: add/expand integration coverage (PENDING)

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

- Introduce `STRIPE_ENABLED` flag and entitlement checks around generation (stub only; free by
  default)
- Stub billing service/interfaces for later Stripe drop-in
- Docs: configuration and upgrade path; note that billing is OFF by default and not required

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

PR 21 — AppSec: exec hardening + scanner tuning

- Exec safety: keep array-form exec for ImageMagick and Node; capture stdout/stderr via `Open3` and
  log failures (DONE for resize/screenshots).
- Input validation: whitelist `fit` values (contain/fill/cover) and raise on invalid; coerce numeric
  args; validate host as HTTP(S) URL (DONE; raise added for `fit`).
- Brakeman tuning: add `config/brakeman.ignore` for two medium “Command Injection” false-positives
  with justification; keep job advisory in CI.
- Weak advisories triage:
  - MyProfilesController: ensure generated paths are derived from sanitized login; guard against
    traversal; document rationale or patch.
  - PagesController: constrain `params[:path]` to known docs folder and allowed basenames; reject
    anything else.
  - OgController: verify `allow_other_host` redirect is intentionally fed by trusted data or add
    domain allowlist.
  - Settings view glob: ensure safe login usage or move lookup behind a helper that enforces safe
    patterns.
- CodeQL: verify default branch has zero new alerts; document policy — new alerts block merges;
  legacy baseline allowed with suppressions where justified.
- Tests: add unit tests for `fit` validation and failure logging paths.

Definition of Done

- CI: tests green; RuboCop/Prettier clean.
- Brakeman: only intentional ignores remain; weak advisory decisions documented or fixed.
- CodeQL: green on default branch; suppression comments link to this PR where applicable.
- Docs: `docs/appsec-ops-overview.md` references this PR in “Roadmap and Gaps”; ignore policy and
  locations documented.

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

- Gemini image provider compatibility (Vertex ↔ AI Studio)
  - Current mitigation: force `gemini.provider: ai_studio` for images to unblock pipelines
  - Provider-specific payloads: implement and verify correct request schema per provider/model
    - Vertex: confirm nesting/field names for image aspect ratio and config (no unknown fields)
    - AI Studio: maintain current working schema
  - Auto-fallback: on Vertex 400 INVALID_ARGUMENT with fieldViolations, auto-switch to AI Studio and
    continue; record event and provider used
  - Healthchecks/canaries:
    - Expose provider-selectable image healthcheck (both providers) and add hourly canary runs
    - Alert on non-2xx with body excerpt and affected provider/model/location
  - Tests (provider matrix):
    - Unit tests for payload builders and response parsers (Vertex/AI Studio; image/text)
    - Integration smokes with recorded fixtures for both providers and image models
    - CI gate to prevent regressions
  - Feature flags/config:
    - Per-stage provider override (images vs traits)
    - Global kill-switch to disable Vertex for images
    - Document precedence: credentials > env > inference
  - Observability & UX:
    - Structured logs: provider, model, endpoint, http_status, field_violations
    - Surface last image provider on profile status page/admin
    - Ops runbook: quotas, regions, model access, common 400/403/429 remedies
  - Acceptance criteria:
    - Vertex image requests succeed with correct schema OR auto-fallback seamlessly uses AI Studio
    - Healthchecks green for both providers in prod; canary alerts wired
    - Test matrix and CI checks in place; docs and runbook updated

Raw Profiles deprecation

- Remove public references and links to `/raw_profiles` in UI (landing, examples)
- Keep routes for legacy/testing temporarily; restrict access behind admin flag if needed
- Move raw JSON/profile refresh to owner-only tools within `My Profiles` settings
- Add a button to refresh raw profile data in settings; show last synced timestamp
- DoD: UI has no raw links; settings include refresh; docs updated

## Next Up (sequenced TODOs)

PR 19 — Directory Listing (browse) (DONE)

- Page `/directory` lists recent successful profiles with pagination
- Filters: search, tag, language, hireable, active, mine, archetype, spirit
- Sorting: most recent first
- Tests: add coverage for filters and pagination (PENDING)

PR 20 — OG Image Route + Pre‑Gen (DONE)

- Route: `/og/:login` returns the generated image (302 to CDN URL when uploaded) or 202 + enqueue
- Hook: on submission/successful sync, share routes link to OG; artifacts recorded under
  `public/generated/<login>`
- Tests: expand 202→ready integration (PENDING)

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

PR 31 — Observability polish (NEW)

- Add a simple request log enricher in controllers (uses `Current.*`) to include user, ip, path.
- Add correlation id to `ServiceResult.metadata` across orchestrated calls.
- DoD: structured logs include `request_id` and `correlation_id`; sample traces in docs.

PR 32 — AI traits analytics (NEW)

- Persist AI traits `attempts` count and `provider/model` metadata on `ProfileCard` when available.
- DoD: fields present; pipeline populates when AI traits succeed; surfaced in JSON.

PR 33 — Mobile polish for cards-first profile page (NEW)

- When shipping the cards-first page, add small-screen font/spacing tweaks and lazy-load images.
- DoD: Lighthouse mobile score improved; CLS below threshold; images have `loading="lazy"` where
  appropriate.
