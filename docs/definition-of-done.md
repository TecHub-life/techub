# Definition of Done (DoD) — Guide and Examples

Use this guide to write tight, testable DoDs for features. Each DoD should be checkable locally.

## Core Checklist

- Code: implementation scoped to the feature; behind flags if risky
- Tests: unit + integration for success and failure paths; hermetic stubs
- Docs: user journey and workflow docs updated; examples included
- Observability: structured logs, artifacts, and metrics where applicable
- Operability: flags/toggles, predictable failure behavior, and rollback notes

## What Good Looks Like — Services

- Inputs validated upfront; returns `ServiceResult`
- Success returns minimal, structured payload; Failure carries error + metadata
- Logs include `service`, `status`, `error_class`, and key metadata
- Tests cover: valid input, invalid input, external failure (e.g., API), and idempotence

Example (Scrape service)

- Command: `bundle exec rails test test/services/scraping/scrape_url_service_test.rb`
- Expected: “5 runs, 0 failures”
- Inspect: On success, value has `title`, `description`, `canonical_url`, capped `text`, and ≤ 50
  links
- Failure cases: invalid URL, SSRF, non-HTML, redirects

## What Good Looks Like — Pipeline Steps

- Stage markers in logs; each step returns `ServiceResult`
- Feature flags guard optional/expensive steps
- Non-fatal optional steps log warnings and continue
- Artifacts saved and inspectable (e.g., prompts under `public/generated/<login>/meta`)

Example (Eligibility gate)

- Env: `REQUIRE_PROFILE_ELIGIBILITY=1`
- Behavior: pipeline fails fast with `error.message = "profile_not_eligible"` and `eligibility`
  metadata
- Tests: enable/disable flag; assert both acceptance and denial paths

Example (Manual inputs)

- Env: `SUBMISSION_MANUAL_INPUTS_ENABLED=1`
- Behavior: pipeline ingests submitted repos and records scrape if present; flag off means no calls
- Tests: assert no calls with flag off; success with flag on

## Template for DoD in Roadmap

- Code: ...
- Tests: ...
- Docs: ...
- Observability: ...
- Operability: ...

Keep DoDs concrete: list exact tests, commands, and artifacts to verify.
