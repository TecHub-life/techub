# ADR-0002: Screenshot generation driver — Node Puppeteer

## Status

Accepted

## Date

2025-10-11

## Context

TechHub generates Open Graph and card images by rendering fixed-size routes and capturing PNG
screenshots. We need a reliable, maintainable way to automate browser rendering in non-interactive
environments (local dev, CI, and production workers). Two primary options were evaluated:

- Node Puppeteer (current: `script/screenshot.js` invoked via `node`)
- puppeteer-ruby gem (Ruby bindings that control Chromium directly)

Constraints and priorities:

- Keep tests deterministic and fast (no real browser in test env)
- Minimize operational complexity in CI/containers
- Prefer well-maintained ecosystems and clear upgrade paths

## Decision

Standardize on Node Puppeteer as the screenshot driver.

Implementation notes:

- Use `script/screenshot.js` to drive rendering and capture; `Screenshots::CaptureCardService`
  shells out to Node in non-test environments.
- Tests avoid Node by writing a tiny PNG header in test env; job/service tests stub where needed.
- Containers install system Chromium; Puppeteer is installed via npm and configured to use the
  system Chromium or its bundled Chromium as appropriate for the environment.

## Rationale

- Maturity and ecosystem: Node Puppeteer has first-party support and frequent updates.
- Operational clarity: We already have a Node toolchain for assets and Prettier. Keeping the driver
  in Node reduces Ruby gem surface and avoids native bindings.
- Separation of concerns: The capture logic stays in a dedicated script easily runnable outside
  Rails for debugging.
- Test friendliness: Current tests bypass Node; no change required and the suite remains fast.

## Decision Drivers

- Maintenance cadence and ecosystem support
- Operational simplicity in containers/CI
- Minimal changes to existing code and developer workflow
- Deterministic, fast tests without real browsers

## Consequences

Positive:

- Predictable behavior across dev/CI/prod with a widely used tool.
- Clear upgrade path following Puppeteer releases.
- Keeps Rails process free from embedding browser control logic.

Negative / Trade-offs:

- Requires Node/npm in the environment where screenshots run.
- Must ensure Chromium availability and sandbox flags in containerized/prod runs.

## Alternatives Considered

1. puppeteer-ruby (https://github.com/YusukeIwaki/puppeteer-ruby)

- Pros
  - No Node/npm dependency at runtime; drive system Chromium directly
  - Single-runtime ops (Ruby-only) possible
  - Familiar from previous projects (e.g., TechDeck)
- Cons
  - Lower maintenance activity relative to Node Puppeteer; risk of API drift
  - Need to explicitly manage Chromium executable path and flags across environments
  - Smaller ecosystem and fewer up-to-date guides/integrations
- Why not chosen now
  - We already ship Node for front-end tooling; adding Puppeteer there is straightforward
  - First-party maintained Node Puppeteer offers faster updates and clearer upgrade paths
  - Keeps screenshot logic isolated in a small Node script, avoiding deeper Ruby integration

2. Playwright

- Pros
  - Robust cross-browser automation with strong CI story
  - Modern API and good stability
- Cons
  - Larger runtime/deps; no current code or scripts in this repo
  - Overkill for our fixed-route screenshots today
- Status
  - Deferred; may revisit if we need cross-browser coverage or Playwright-specific features

## Implementation Status

- Implemented. `Screenshots::CaptureCardService` uses Node in non-test, and tests bypass Node.
- Docker image installs `chromium`; `npm install` ensures Puppeteer is available where needed.

## Operational Guidance

- Local: `npm install` and run `rake screenshots:capture[login,variant]` (set `APP_HOST` if needed).
- CI/Prod: Ensure Puppeteer installs (use `npm ci`), and pass `--no-sandbox` flags when running in
  containers without user namespaces (already done in `script/screenshot.js`). Optionally set
  `PUPPETEER_SKIP_DOWNLOAD=1` to prefer system Chromium.
- Runtime model: Web and background jobs run from the same container image. We will validate this
  locally via Docker Compose with service healthchecks before promoting.

## Review Date

2026-01-31 — Reassess if Playwright or a service-based renderer becomes preferable.

## Decision Makers

Core maintainers (TechHub project).

## Related ADRs

- ADR-0001 — LLM cost control via eligibility gate

## References

- docs/og-images.md — routes and sizes for OG/card renders
- script/screenshot.js — Node helper script
- app/services/screenshots/capture_card_service.rb — service wrapper
- puppeteer-ruby — https://github.com/YusukeIwaki/puppeteer-ruby
