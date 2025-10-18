## AI Controls: Generation Policy, Triggers, and Admin/User Access

### Overview

- AI costed actions (traits/images) run only when explicitly requested.
- First-time submission: AI runs once; subsequent runs require user/admin action.
- Users are throttled (weekly) for AI regeneration; admins are not throttled.

### User Controls

- Settings page (`MyProfilesController`):
  - Re-capture (no AI): always allowed, queues pipeline with `ai: false`.
  - Regenerate AI: allowed when `Time.current >= last_ai_regenerated_at + 7.days`.
  - UI exposes next allowed time via `@ai_regen_available_at`.
- Ownership:
  - Users can only manage profiles they own.
  - Ownership cap enforced (`PROFILE_OWNERSHIP_CAP`, default 5); page displays cap, current,
    remaining.

### Admin Controls

- Ops panel:
  - Retry (no AI) and Retry AI actions available per profile; admins bypass throttling.
- Rake tasks:
  - `rake ai:traits[login]` regenerate AI traits for a single profile.
  - `rake ai:traits_bulk[logins]` regenerate AI traits for multiple profiles.
  - `rake ai:images[login]` regenerate AI images for a single profile.

### When AI Runs

- Submission flow (`Profiles::SubmitProfileJob`):
  - Enqueues pipeline with `ai: true` only if the profile has no `profile_card` and
    `last_ai_regenerated_at` is nil (first creation).
  - Otherwise enqueues with `ai: false`.
- My profiles settings:
  - Re-capture: `ai: false`.
  - Regenerate AI: `ai: true` with weekly backoff.
- Ops panel/admin rake: admin may run traits/images at any time.

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

- OG controller queues pipeline with `ai: false` when images are missing, avoiding unintended AI
  costs.

### Testing Coverage

- Pipeline orchestration, eligibility flag gating, and submission AI-first-run behavior are tested.
- Sync tests ensure fields/associations are preserved when sections are missing.
