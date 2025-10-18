## Asset Selection Workflow (Planned)

### Purpose

Define how users and admins select avatars and artwork per card variant without deleting previously
generated/uploaded assets. This plan supports a separate PR.

### Principles

- Never delete generated or uploaded assets; keep history for future gallery/selection.
- Maintain a single current screenshot per variant (OG, Card, Simple) while preserving source
  assets.
- User-triggered AI actions are throttled (weekly); admins are unthrottled.

### Scope (v1)

- Variants: `og`, `card`, `simple`.
- Avatar source per variant:
  - Real avatar (GitHub/local cached) OR
  - One of N AI-generated avatar variants.
- Artwork/background per variant:
  - Choose from generated backgrounds (existing AI outputs) or default.
- Per-variant selection:
  - Allow different avatar and artwork choices for each of the three variants.

  > **Note**: We need to generate the assets for the variants before we can select them. The way we
  > are generating the assets now is probably wrong for what we actually need.

### Data Model (proposal)

- Reuse `ProfileAsset` for persisted files (already exists for card/og/simple and uploads).
- Add `asset_kind` and `variant` conventions if needed:
  - Avatar assets: `asset_type = "avatar"` (values: `real`, `ai`); `variant` optional label (e.g.,
    `v1`, `v2`).
  - Background assets: `asset_type = "background"`; `variant` in { `og`, `card`, `simple` }.
- Introduce `ProfileAssetSelection` (new table) to bind selections:
  - Columns: `profile_id`, `variant` (og/card/simple), `avatar_asset_id` (nullable, nil means real),
    `background_asset_id` (nullable), timestamps.
  - Unique index on (`profile_id`, `variant`).

### Pipeline Changes

- AI image generation produces multiple avatar variants and background candidates (no deletion),
  persisted as `ProfileAsset` records with appropriate `asset_type`/`variant`.
- Screenshot/capture stage reads `ProfileAssetSelection` for:
  - Avatar: real (default) or selected AI avatar asset.
  - Background: selected asset or default if none.
- Fallbacks: if a selected asset is missing, revert to real avatar and default background.

### User Interface (Settings)

- For each variant (OG, Card, Simple):
  - Avatar choice: radio (Real avatar) or select (AI variants list).
  - Artwork choice: select from available backgrounds.
- Save writes/creates `ProfileAssetSelection` rows.

### Admin UI (Ops)

- Optional bulk tools to set/reset selections per variant.
- No throttling for admin-triggered new generation.

### Costs and Throttling

- Throttling remains user-only for AI generation.
- Admin can generate at will.

### Out of Scope (v1)

- User-uploaded custom artwork as selectable backgrounds (will integrate later into `ProfileAsset`).
- Full gallery browsing/filtering and rich previews across history.

### Migration Plan

- Create `profile_asset_selections` with (`profile_id`, `variant`, `avatar_asset_id`,
  `background_asset_id`).
- Backfill: create default selection rows with `avatar_asset_id = NULL` (real) and
  `background_asset_id = NULL` (default).

### Test Plan

- Model: validations and unique (`profile_id`, `variant`).
- Service: pipeline respects selections (avatar/background) when capturing.
- Controller/Views: settings page persists selections per variant; default/fallback behavior
  covered.

### Rollout

- Deploy schema and code behind a feature flag (e.g., `asset_selection_v1`).
- Enable flag for internal users first; verify costs and performance; then enable for all.
