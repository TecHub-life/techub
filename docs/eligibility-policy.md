# Profile Eligibility Policy

Status: Enforced by default in pipeline

Purpose

- Ensure TecHub only processes meaningful, public‑signal GitHub profiles to protect AI budget and
  keep quality high.

Signals (Eligibility::GithubProfileScoreService)

- Account age: ≥ 60 days
- Repository activity: ≥ 3 owned, non‑archived public repos with pushes in the last 12 months
- Social proof: followers ≥ 3 OR following ≥ 3
- Meaningful profile: bio present OR profile README present OR pinned repositories exist
- Recent public events: ≥ 5 in last 90 days

Scoring

- Each signal met counts as 1 point
- Default threshold: 3/5 → eligible

Default Behavior

- Gating is ON by default. The pipeline denies generation when a profile is not eligible and returns
  failure with structured metadata (score, threshold, signals).
- To disable (rare; e.g., paid/Stripe mode), set `REQUIRE_PROFILE_ELIGIBILITY=0`.

Implementation

- Service: `Eligibility::GithubProfileScoreService`
- Pipeline enforcement: `Profiles::GeneratePipelineService` (default on; FeatureFlags)
- Docs: docs/user-journey.md, docs/roadmap.md (PR 14), ADR‑0001

Testing

- Unit tests cover pass/fail and signal calculations
- Pipeline tests verify failure with gate enabled and bypass when explicitly disabled

Notes

- Signals and thresholds are configurable; adjust only with product review
- Denial should surface reasons to the user (UI copy to be added when submission UI ships)
