---
name: Feature Request (with DoD)
about: Propose a roadmap item with a clear Definition of Done
labels: enhancement
---

## Summary

Describe the feature and the user impact.

## Context / Links

- Related roadmap item: (e.g., docs/roadmap.md:PR XX)
- User journey/docs: docs/user-journey.md
- Workflow/spec: docs/application-workflow.md, docs/submit-manual-inputs-workflow.md

## Scope

- In scope:
- Out of scope:

## Flags

- New/used flags (default off):
  - [ ] REQUIRE_PROFILE_ELIGIBILITY
  - [ ] SUBMISSION_MANUAL_INPUTS_ENABLED

## Definition of Done

- Code
  - [ ] Implementation scoped to feature; risky parts behind flags
  - [ ] Returns `ServiceResult` and logs with `service`, `status`, `error_class`
- Tests
  - [ ] Unit tests for success and failure paths
  - [ ] Integration test if applicable (pipeline/controller)
- Docs
  - [ ] Update docs/user-journey.md and relevant workflow docs
  - [ ] Update docs/roadmap.md item status
- Observability
  - [ ] Structured logs include stage markers and key metadata
  - [ ] Artifacts saved/inspectable (where applicable)
- Operability
  - [ ] Feature flag documented and defaulted off
  - [ ] Rollback notes

## Acceptance Steps

List exact commands and expected outputs (e.g., test commands, artifacts paths).
