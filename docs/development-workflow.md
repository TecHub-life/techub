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

## Service pattern

All services inherit from `ApplicationService` and expose `.call`:

```ruby
result = SomeService.call(arg: 1)
if result.success?
  do_something(result.value)
else
  Rails.logger.warn(result.error, metadata: result.metadata)
end
```

Prefer composing smaller services inside a coordinator service that returns a single
success/failure, passing along rich `metadata` for traceability.

## Gemini helpers

For Gemini API integrations, use shared helpers:

- `Gemini::Endpoints` centralises endpoint paths for both providers (AI Studio and Vertex).
- `Gemini::ResponseHelpers` provides `normalize_to_hash`, `parse_relaxed_json`, and `dig_value` for
  resilient parsing of provider responses.

Example usage inside a service:

```ruby
include Gemini::ResponseHelpers

path = Gemini::Endpoints.text_generate_path(
  provider: provider,
  model: Gemini::Configuration.model,
  project_id: Gemini::Configuration.project_id,
  location: Gemini::Configuration.location
)
response = conn.post(path, payload)

data = normalize_to_hash(response.body)
candidate = Array(dig_value(data, :candidates)).first
```

These helpers improve consistency, reduce duplication, and make tests simpler.
