# TecHub — End‑to‑End Plan (Living)

Purpose

- Provide a concise, repo‑aligned plan for TecHub across product, AI/media, pipeline, UX, and ops.
- Anchor open questions and next steps so context from this session is captured and actionable.

Product Vision

- AI‑assisted trading cards for GitHub profiles with high‑quality art and shareable OG images.
- Users can: sign in with GitHub, generate profiles + media, curate avatars/backgrounds per card,
  and share.
- Keep the experience portable and operable from a laptop; production uses DO Spaces for assets.

Core User Flows

- Submit/Sync: Ingest GitHub profile, repos, orgs, languages, README; cache avatar locally.
- Generate: AI text traits + multiple art variants; produce OG, card, and simple screenshots.
- Curate: From Settings, select avatar and background per variant; upload custom images when
  desired.
- Share: Public profile shows the card(s); `/og/:login` serves OG image for link previews.

Architecture Overview

- Rails 8 app with SQLite, Solid Queue, Tailwind, Kamal deploys (see README).
- Active Storage for asset uploads; DigitalOcean Spaces in production.
- Gemini 2.5 Flash for text, avatar description, and image generation with structured output.
- Services return `ServiceResult` for predictable orchestration and logging.

AI + Media System

- Inputs: GitHub profile + structured context (languages, repos, orgs, activity, README excerpt).
- Text/traits: `Profiles::SynthesizeAiProfileService` enforces constraints and fallbacks.
- Avatar description: `Gemini::AvatarPromptService` synthesizes prompts with style/theme.
- Image gen: `Gemini::AvatarImageSuiteService` targets 1:1, 16:9, 3:1, 9:16 variants and records
  assets.
- OG: Screenshot fixed‑size route with Puppeteer/Playwright; heavy optimization offloaded to jobs.

Image Ratios & Quality — Fixes

- Action: Pass explicit aspect ratio parameters to Gemini image generation, not just in prompt text.
  - Update `Gemini::ImageGenerationService` to include provider‑specific ratio fields; keep prompt
    hints as backup.
  - If provider ignores ratios, generate at a safe larger size and crop deterministically per
    variant.
- Action: Make background positioning predictable.
  - Use existing `profile_cards.bg_fx_* / bg_fy_* / bg_zoom_*` to store per‑view crop/zoom; expose
    simple controls in Settings.
- Action: Standardize target sizes and progressive JPEG for large backgrounds; keep PNG where
  transparency is needed.

Media Library & Selection

- Keep a canonical latest asset per kind in `ProfileAssets` and preserve a history of candidates.
- Add selectable sources per variant (OG, Card, Simple):
  - Avatar: real GitHub avatar or any generated avatar.
  - Background: any generated background or default/color.
- Data model extension:
  - Add `profile_asset_selections` to bind per‑variant choices: (`profile_id`, `variant`,
    `avatar_asset_id`, `background_asset_id`).
  - Optionally add `profile_backgrounds` for multiple background candidates (16:9, 3:1, etc.) with a
    `selected` flag.
- Pipeline reads selections; fall back to canonical/latest when none selected.

Settings UX (Owners)

- Per variant (OG, Card, Simple): show preview + selectors.
- Avatar selection: radio for real avatar; gallery for generated avatars; show creation time and
  provider.
- Background selection: gallery of generated backgrounds; allow solid color fallback.
- Uploads: keep current upload overrides for `og`, `card`, `simple`, and `avatar_3x1`.
- Generation status: show last run, errors, and next allowed AI regeneration time.

Generation Controls & Limits

- Non‑AI recapture: Unlimited; re‑screenshot routes and re‑optimize.
- AI regeneration: Rate‑limited (weekly per profile) with clear countdown in Settings.
- Eligibility gate: Use signals (age, activity, social proof) to guard spend; surface decline
  reasons.

Data Model (aligned with current repo)

- Continue using structured `profiles` + `profile_card` + `profile_assets`.
- Additions:
  - `profile_asset_selections` (unique per profile + variant) for avatar/background choices.
  - Optional `profile_backgrounds` to store multiple candidates with `selected` flag and retention
    policy.

Pipeline Orchestration

- Orchestrate: sync → avatar description → text traits → images → screenshots → optimize/upload →
  record assets.
- Persist artifacts (`public/generated/<login>/meta/*.json`) for auditing; upload to Spaces when
  enabled.
- Emit structured logs at each stage with correlation id; surface in Mission Control.

Ops & Observability

- Health: `/up`, `/up/gemini`, `/up/gemini/image`.
- Jobs UI: Mission Control mounted for queue visibility.
- Metrics: structured logs for attempts, durations, retries, upload success, and size savings.
- Runbooks: follow `docs/ops-runbook.md`, `docs/ops-admin.md`, `docs/image-optimization.md`.

Physical Cards (Later)

- Export print‑ready images (e.g., 300 DPI with bleed) from card templates.
- Add a print integration step with order webhooks; keep decoupled from core generation.

Milestones (sequenced)

1. Ratios & Cropping Reliability

- Pass provider ratio flags; add deterministic crop/zoom controls; lock target sizes.

2. Media Selection v1

- Schema: `profile_asset_selections`; Settings UI for avatar/background per variant; pipeline reads
  selections.

3. Background Candidates v1 (optional)

- Schema: `profile_backgrounds`; write all candidates; selection UI; retention job keeps last N per
  kind.

4. Avatar Gallery

- Generate multiple avatar styles; store as `ProfileAssets` with variant labels; add selection UI.

5. Public Profile (cards‑first)

- Replace interim profile page; use generated text + assets; add share actions and OG correctness.

6. Print Export (optional)

- Add print export sizes and a basic fulfillment integration behind a feature flag.

Knowledge Capture (don’t lose context)

- Living plan: this file captures scope and next steps; update alongside changes.
- Decisions: add short ADRs for material choices in `docs/adr/` and session notes under
  `docs/notes/`.
- Roadmap: continue using `docs/roadmap.md` for PR‑sized items; link to specs like
  `AI_PROFILE_GENERATION_PLAN.md`.

Open Questions

- How many avatar styles per run should we offer in v1 (cost vs value)?
- Do we want per‑card theme presets in Settings now or after media selection ships?
