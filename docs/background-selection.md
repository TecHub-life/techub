Background Selection – Storage & UX Plan

Goal

- Allow profile owners to pick from multiple generated background images (primarily 16:9) for their
  card/OG renders.

Storage Plan

- Keep `ProfileAssets` as the canonical single latest asset per kind (`og`, `card`, `simple`,
  `avatar_*`). Owners may upload to overwrite these canonical assets.
- Add a new table `profile_backgrounds` (to be implemented) for multiple candidates:
  - `profile_id` (FK)
  - `kind` (`bg_16x9`, `bg_card`, optionally `bg_3x1`)
  - `local_path`, `public_url`, `provider`
  - `sha256` (optional de‑dup)
  - `generated_at`, `created_at`, `updated_at`
  - `selected` (boolean) – exactly one selected per `profile_id`+`kind` at a time
- Files on disk: `public/generated/<login>/backgrounds/<kind>-<timestamp>.jpg`
- In DO Spaces: `generated/<login>/backgrounds/<kind>-<timestamp>.jpg` (public URL via Active
  Storage)

Generation

- On each generation, continue to write the latest to `ProfileAssets` for current flows.
- Additionally, insert a `profile_backgrounds` row for each candidate written; upload to Spaces when
  enabled.

Owner uploads

- Owners can upload/overwrite canonical assets for: `og`, `card`, `simple`, and `avatar_3x1` (3×1
  banner).
- Uploaded assets take precedence in renders; they overwrite the single latest record per kind.
- UI: My Profile → Settings includes upload forms; overwriting is explicit.

Selection & Rendering

- Profile Settings shows recent backgrounds per kind with a “Select” action.
- Screenshots and OG routes prefer the selected background when present; otherwise fall back to the
  latest.

Retention & Hygiene

- Optional recurring prune job keeps the last N=5 per kind; preserves the selected row regardless of
  age.
- Structured logs for background writes, selections, and prunes.

Tests (high‑value)

- Selecting a background updates which image is used for OG/card.
- Prune respects `selected` and keeps the latest N.
- Upload/write paths correctly recorded; OG route and screenshots detect the selection.
