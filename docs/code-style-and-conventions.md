# Code style and conventions

## Logging to Axiom

- We follow the Axiom Rails/Faraday guide: JSON logs to STDOUT, optional Faraday ingest if
  `AXIOM_TOKEN` and `AXIOM_DATASET` are present. See `config/initializers/structured_logging.rb` and
  `docs/observability/axiom-opentelemetry.md`.
- Reference: https://axiom.co/docs/guides/send-logs-from-ruby-on-rails

## RuboCop

- We use `rubocop-rails-omakase` defaults, keeping rules pragmatic and noise low.
- Style reference: https://github.com/rubocop/ruby-style-guide
- Local run: `bin/rubocop` (via CI too). Prefer autocorrect where safe and avoid large unrelated
  reformatting.

## Gemfile ordering

- Group gems logically:
  - Core Rails and platform gems first
  - App/feature gems (HTTP clients, markdown, image processing)
  - Infra/ops (jobs UI, deploy, S3, auth)
  - Dev/test groups at the bottom
- Keep comments short; avoid duplicate entries; prefer stable version constraints only when
  necessary.

## File extensions: .yml vs .yaml

- We standardize on `.yml` throughout the repo (Rails convention and current credentials file).
- When adding new YAML files, use `.yml`. If importing external `.yaml`, consider renaming for
  consistency.

## Docs

- All markdown under `docs/` is listed at `/docs` and rendered with CommonMarker.
- Add new docs as needed; keep them concise and cross-link where helpful.
