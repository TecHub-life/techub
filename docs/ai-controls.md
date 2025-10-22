## Images vs Text: Generation Policy, Triggers, and Access

### Overview

- Image generation is costed; text AI always runs.
- First-time submission: images may run once; subsequent image runs require user/admin action.
- Users are throttled (weekly) for image regeneration; admins are not throttled.

### User Controls

- Settings page (`MyProfilesController`):
  - Re-capture (no new images): always allowed, queues pipeline with `images: false`.
  - Regenerate with images: allowed when `Time.current >= last_ai_regenerated_at + 7.days`.
  - UI exposes next allowed time via `@ai_regen_available_at`.
- Ownership:
  - Users can only manage profiles they own.
  - Ownership cap enforced (`PROFILE_OWNERSHIP_CAP`, default 5); page displays cap, current,
    remaining.

### Admin Controls

- Ops panel:
  - Retry (no new images) available per profile and in bulk; admins bypass throttling.
  - Image regeneration is an explicit, user-facing option in Settings; not exposed for bulk Ops.

### When Images Run

- Submission flow (`Profiles::SubmitProfileJob`):
  - Enqueues pipeline with `images: true` only if the profile has no `profile_card` and
    `last_ai_regenerated_at` is nil (first creation).
  - Otherwise enqueues with `images: false`.
- My profiles settings:
  - Re-capture: `images: false`.
  - Regenerate with images: `images: true` with weekly backoff.
- Recurring freshness:
  - A scheduled job enqueues the pipeline with `images: false` for stale profiles, keeping text and
    screenshots fresh without regenerating AI artwork.
- Admin rakes: no bulk image regeneration; use Ops retry for safe refresh.

### Sync Robustness

- `Profiles::SyncFromGithub` preserves existing scalar fields when payload fields are nil.
- Associations (repos/orgs/social/languages/activity) are only rebuilt when the corresponding
  payload sections are present.

### Success/Failure Plumbing

- All services return `ServiceResult` with success/failure and optional metadata.
- Pipeline job updates `profiles.last_pipeline_status` and `last_pipeline_error`; notifies user and
  ops on failure.
- Sync errors recorded in `profiles.last_sync_error` and `last_sync_error_at`.
- Per-stage events recorder: `ProfilePipelineEvent`.

### Non-AI Triggers

- OG controller queues pipeline with `images: false` when images are missing, avoiding unintended
  image generation costs.

### Testing Coverage

- Pipeline orchestration, eligibility flag gating, and submission AI-first-run behavior are tested.
- Sync tests ensure fields/associations are preserved when sections are missing.
