# Credentials keys (required and optional)

This page lists keys the app can read from Rails encrypted credentials and how they map to ENV or
features.

## Axiom (optional)

- axiom.token: Ingest token → maps to ENV `AXIOM_TOKEN`
- axiom.master_key: Axiom master key for admin APIs (map fields, trimming) → maps to ENV
  `AXIOM_MASTER_KEY`

Everything else (datasets, OTEL endpoint, org slug) is non-secret and now lives in `AppConfig.axiom`
with defaults (`otel-logs` and `otel-traces`). Override via env (`AXIOM_DATASET`,
`AXIOM_TRACES_DATASET`, `AXIOM_METRICS_DATASET`, `AXIOM_BASE_URL`, etc.) only if you need different
names or regions.

References: `config/initializers/axiom.rb`, `config/initializers/structured_logging.rb`. Guide:
https://axiom.co/docs/guides/send-logs-from-ruby-on-rails

## Gemini (image/text generation)

- gemini.image_model (optional; default: gemini-2.5-flash-image)
- gemini.provider (optional; inferred: vertex when project_id present else ai_studio when api_key
  present)
- gemini.project_id (Vertex; required for Vertex provider)
- gemini.location (Vertex; default us-central1)
- gemini.api_key (AI Studio)
- gemini.api_base (AI Studio; default https://generativelanguage.googleapis.com/v1beta)

Alternative lookup paths supported by code (for compatibility):

- google.gemini.image_model
- google.project_id, google.location
- google.ai_studio.api_key, google.ai_studio.api_base
- google.api_key

References: `app/services/gemini/configuration.rb`.

## Mission Control Jobs (optional in production)

- mission_control.jobs.http_basic: "user:password" — enables `/ops/jobs` in production when set

References: `config/routes.rb` (mounting behavior differs by env), `docs/ops-admin.md`.

## Other environment-driven flags (not credentials, but related)

These are usually set as ENV, not in credentials; listed here for awareness.

- GEMINI_INCLUDE_ASPECT_HINT (default on): whether to include aspectRatio in requests
- ACTIVE_STORAGE_SERVICE (default `local` in dev/test): set to `do_spaces` when you want generated
  files uploaded to Spaces outside production
- IMAGE_OPT_VIPS (default off): prefer vips for image optimization/resize
- IM_CLI (optional): override ImageMagick CLI (magick/convert)
- PROFILE_OWNERSHIP_CAP (default 5): cap owned profiles in UI

## Storage (S3/Spaces) (optional)

Active Storage service credentials typically live in `config/storage.yml` + ENV. If using DO
Spaces/S3, ensure the usual keys (access key, secret, endpoint, region, bucket) are set in
environment.

## GitHub App (optional)

If using a GitHub App, there may be keys like:

- github.installation_id (optional) — used for app-scoped operations (if implemented in your
  environment)

## Notes

- The masked export at `config/credentials.example.yml` shows current structure but omits unset
  optional fields. Use this page to cross-check optional ones.
- The `.env.from_credentials.example` file enumerates all discovered keys as flattened env
  placeholders.
