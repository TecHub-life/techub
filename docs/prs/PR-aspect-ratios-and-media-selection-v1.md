# PR: Image Ratios, Media Selection v1, and Cropping Controls

Summary

Fix reliability of image ratios/aspect handling in AI image generation, add per‑variant media
selection (avatar/background) groundwork, and expose basic crop/zoom controls for backgrounds used
by Card/OG/Simple renders.

Why

- Current image generation does not pass explicit aspect ratio fields to the provider; ratio is only
  hinted in the prompt. This leads to mismatched sizes and awkward crops.
- Owners need to choose between their real avatar and generated avatars, and select any generated
  background for any variant.
- Background positioning needs predictable, user‑tunable framing across views.

Scope

- Wire provider‑specific aspect ratio hints in `Gemini::ImageGenerationService` (non‑breaking) and
  keep prompt hints as fallback.
- Introduce a small selection schema (`profile_asset_selections`) to bind chosen avatar/background
  per variant (OG/Card/Simple).
- Extend Settings with basic galleries for avatar/background selection (reads from `ProfileAssets`).
- Add simple x/y/zoom inputs bound to existing `profile_cards.bg_*` columns; read in screenshots.

Out of Scope

- Full background candidates table + retention (optional follow‑up).
- Multi‑style avatar gallery generation (follow‑up once selection path exists).

Design

- Aspect ratio: add optional payload fields recognized by the image endpoint when available; keep
  current prompt structure. If the provider ignores explicit fields, we generate at a safe dimension
  and crop deterministically during screenshots.
- Selections: a single row per variant stores chosen `avatar_asset_id` (nullable = real avatar) and
  `background_asset_id` (nullable = default/AI latest). Pipeline reads selection or falls back.
- Cropping: reuse `profile_cards.bg_fx_*`, `bg_fy_*`, `bg_zoom_*` per view; expose in Settings.

Data Model

- New: `profile_asset_selections` with unique (`profile_id`, `variant`), columns: `avatar_asset_id`
  (nullable), `background_asset_id` (nullable), timestamps.

Migration Plan

1. Add `profile_asset_selections` table and unique index.
2. Backfill one row per profile with all fields NULL (defaults: real avatar + AI latest/background
   default).
3. No changes to existing `profile_assets` data.

Code Changes

- app/services/gemini/image_generation_service.rb: accept and encode aspect ratio field(s) per
  provider; include in artifacts/logs.
- app/views/my_profiles/settings.html.erb: add avatar/background selection UIs; add crop/zoom inputs
  for Card/OG/Simple.
- app/controllers/my_profiles_controller.rb: permit selection params and save to
  `profile_asset_selections`.
- app/jobs/screenshots/capture_card_job.rb and render helpers: respect selection + crop/zoom values.

Risks

- Provider payload differences; mitigate by gating aspect ratio fields behind provider checks and
  leaving prompts intact.
- UI complexity; ship a minimal gallery list first, then iterate.

Validation

- Health checks: `/up/gemini/image` returns 200 after changes.
- Visual: generate a set for a known profile and confirm 1:1, 16:9, 3:1, 9:16 compositions frame
  correctly in screenshots.
- Selections: switch avatar/background and confirm the screenshots and `/og/:login` reflect choices.

Related Issues

- #83 Improve image generation and include different image sizes and more
- #60 User should be able to use any artwork we have available in any of their images
- #64 AI generated avatar selection by users
- #77 Settings page polish (selection UI and controls)
