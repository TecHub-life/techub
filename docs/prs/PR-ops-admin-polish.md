# PR: Ops/Admin Polish (Queue, Actions, Visibility)

Summary

Make Ops more actionable and readable without changing product UI. Focus on job actions, selection
overrides, and structured visibility.

Scope

- Actions (buttons) per profile in Ops:
  - Re‑capture Screenshots (non‑AI)
  - Regenerate AI Artwork (ignore cooldown for admins)
  - Re‑optimize large assets (Images::OptimizeJob)
  - Set Avatar Choice (real/AI) quick toggle
- Visibility:
  - Show last pipeline status, stage timestamps, last error (truncated), links to Card/OG/Simple
  - Link to latest generated assets + CDN URLs if present
  - Correlation/request IDs per pipeline run
- Logs:
  - Surface `StructuredLogger` lines filtered by `login:` in a simple viewer (best‑effort)

Implementation Plan

1. Controller endpoints

- Add admin‑scoped POST endpoints that enqueue the respective jobs or update avatar_choice.
- Return to Ops list with flash.

2. Ops views

- Add a compact table: Profile, Status, Last Run, Actions, Artifacts/Links.
- Add a detail drawer per row for error and event timeline (optional).

3. Policy & Security

- HTTP Basic or current admin check consistent with existing Mission Control access.
- Read‑only for non‑admin; buttons hidden.

4. Observability

- Emit structured logs for each admin action: `ops_action_invoked` with `action`, `login`, and
  `request_id`.

Out of Scope (this PR)

- Complex log viewer with search; keep to simple filtered output.
- Full moderation or content flags.

Validation

- Trigger each action; verify jobs are queued and settings updated.
- Navigate links to Card/OG/Simple and latest CDN assets.
- Confirm structured logs for admin actions appear with expected fields.
