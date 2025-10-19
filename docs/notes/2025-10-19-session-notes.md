# Session Notes — 2025-10-19

Context

- Goal: capture the conversation’s decisions so they aren’t lost and roll them into a living plan.
- Scope: TecHub only; focus on avatar/media pipeline, user selection, and reliable ratios.

Decisions

- Keep the plan and specs in‑repo under `docs/`, not external gists.
- Maintain a living end‑to‑end plan (`docs/end-to-end-plan.md`); update as features ship.
- Record material choices as short ADRs in `docs/adr/`; use session notes (`docs/notes/`) for
  context that doesn’t warrant a full ADR.
- Focus on TecHub’s media/AI integration and selection UX.
- Avatars: allow choosing the real GitHub avatar or generated avatars; keep avatars “strict”
  (identity‑preserving) with style variations.
- Backgrounds: generate multiple aspect‑friendly artworks intended to be safely cropped/zoomed;
  users can select any artwork for any card variant.
- Media library: treat generated assets as a per‑profile library; selection is per‑variant (OG,
  Card, Simple).
- Regeneration: time‑limited (weekly) for AI; unlimited re‑capture for non‑AI screenshots.
- Ratios: fix by passing explicit provider fields for aspect ratio; backstop with deterministic
  crop/zoom and target sizes.

Action Items (near‑term)

1. Aspect ratio support

- Update `Gemini::ImageGenerationService` to send provider‑correct ratio fields; keep prompt hints.
- Verify on `/up/gemini/image`; record provider + ratio in logs and artifacts.

2. Selection schema and UI

- Add `profile_asset_selections` for per‑variant avatar/background choices.
- Extend Settings to show avatar gallery and background gallery; wire to selection service.

3. Background candidates (optional v1)

- Add `profile_backgrounds` to store multiple 16:9 and 3:1 candidates with a `selected` flag and
  retention.

4. Cropping controls

- Expose simple x/y/zoom controls using existing `profile_cards.bg_*` columns for OG/Card/Simple.

5. Print export (later)

- Define print‑ready export sizes/bleed; keep integration behind a feature flag.

Where to Look

- AI profile + images: `AI_PROFILE_GENERATION_PLAN.md`, `app/services/gemini/*`.
- Selection plans: `docs/asset-selection-workflow.md`, `docs/background-selection.md`.
- Roadmap and ops: `docs/roadmap.md`, `docs/ops-runbook.md`, `docs/gemini-setup.md`.
