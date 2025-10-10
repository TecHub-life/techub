# Development Workflow

- **One feature per PR**. Keep branches tight so each change remains reviewable and reversible.
- **SOLID-aligned services**. Prefer service objects that expose a single responsibility and inherit
  from `ApplicationService`.
- **ServiceResult everywhere**. Services must return `ServiceResult.success` or `.failure` so
  callers can pattern-match on `success?` / `failure?` without nil checks.
- **Tests that matter**. Every new behaviour ships with a test that proves the happy path and
  validates the failure surface when it adds value.
- **Local CI must be green**. Run `bin/ci` before you push. A feature is “done” only when code,
  docs, and tests land together with a passing pipeline.
