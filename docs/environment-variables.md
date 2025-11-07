# Environment Variables Inventory and Where They Should Live

This doc enumerates all environment variables referenced in the repo, the recommended home for each
value, and rationale. Treat `.env` as local overrides only; do not rely on it for durable
application behavior.

## Rails Configuration Layers

- `config/application.rb`
  - App-wide defaults that rarely vary by environment (e.g., middleware, generators).
- `config/environments/*.rb`
  - Per-environment overrides (development, test, production). Use this for true environment
    differences (caching, logging, asset hosting).
- Encrypted credentials (`config/credentials.yml.enc`)
  - Secrets and provider keys/tokens. Prefer to store here vs. env.
- App settings (database)
  - Operator‑controlled toggles that must persist across deploys (e.g., feature and cost flags). Use
    `AppSetting` and expose in Ops.
- `.env`
  - Local developer overrides only. Keep minimal. Never required for production.

## Inventory and Recommendations

Secrets/Credentials (store in credentials; env only as last‑resort override)

- GitHub: `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GITHUB_WEBHOOK_SECRET`,
  `GITHUB_PRIVATE_KEY`/`GITHUB_PRIVATE_KEY_PATH`, `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`,
  `GITHUB_CALLBACK_URL_PROD`, `GITHUB_CALLBACK_URL_DEV`, `GITHUB_SETUP_URL`
  - Home: credentials under `:github`.
  - Refs: app/controllers/sessions_controller.rb:1, app/services/github/\*.rb, config/routes.rb:21.
- Gemini/Google: `GEMINI_API_KEY`, `GEMINI_API_BASE`, `GOOGLE_CLOUD_PROJECT`, `GEMINI_LOCATION`,
  optional `GEMINI_PROVIDER`
  - Home: credentials under `:gemini`/`:google`.
  - Refs: app/services/gemini/configuration.rb:1.
- DO Spaces/S3: `DO_SPACES_ACCESS_KEY_ID`, `DO_SPACES_SECRET_ACCESS_KEY`, `DO_SPACES_ENDPOINT`,
  `DO_SPACES_CDN`, `DO_SPACES_REGION`, `DO_SPACES_BUCKET`
  - Home: credentials under `:do_spaces`.
  - Refs: config/storage.yml:12,17,19,21; app/services/backups/\*.
- Resend: `RESEND_API_KEY`
  - Home: credentials under `:resend`.
- Axiom/OTEL:
  - `AXIOM_TOKEN` — required for OTEL export and dataset ingest (maps from credentials)
  - `AXIOM_DATASET` — logs/events dataset name (maps from credentials). Keep this for JSON logs.
  - `AXIOM_METRICS_DATASET` — default dataset for OTEL traces + metrics (falls back to
    `AXIOM_DATASET` if unset). Use this to keep within the two-dataset free tier.
  - `AXIOM_TRACES_DATASET` — optional traces dataset override (falls back to
    `AXIOM_METRICS_DATASET`, then `AXIOM_DATASET`)
  - `AXIOM_ORG` — Axiom org slug (for Ops UI deep-links only; optional)
  - `AXIOM_BASE_URL` — region base URL. Default US `https://api.axiom.co`; EU:
    `https://api.eu.axiom.co`
  - `AXIOM_ENABLED` — optional override. Default: production forwards automatically when token +
    dataset are present; other environments stay off unless this flag is set to `1`.
  - `OTEL_EXPORTER_OTLP_ENDPOINT` — OTEL base endpoint (default US traces endpoint)
    - US: `https://api.axiom.co/v1/traces`
    - EU: `https://api.eu.axiom.co/v1/traces`
  - `OTEL_METRICS_EXPORT_INTERVAL_MS` — metrics export interval (default 60000) for dev forcing.
  - Refs: config/initializers/structured_logging.rb, config/initializers/axiom.rb,
    config/initializers/opentelemetry.rb, app/services/axiom/ingest_service.rb,
    .github/workflows/ci.yml, .github/workflows/kamal-deploy.yml.
- Twitter meta: `TWITTER_SITE_HANDLE`, `TWITTER_CREATOR_HANDLE`
  - Home: credentials under `:twitter`.
  - Refs: app/views/layouts/application.html.erb:42.

App/DB‑backed settings (use AppSetting and Ops; do not use env)

- AI cost/feature gates: image generation, image descriptions
  - Keys: `AppSetting[:ai_images]`, `AppSetting[:ai_image_descriptions]` (default false).
  - Refs: config/initializers/feature_flags.rb:1, app/controllers/ops/admin_controller.rb:25.
- Access control: allowlist and open access
  - Keys: `AppSetting[:allowed_logins]`, `AppSetting[:open_access]`.
  - Refs: app/services/access/policy.rb:1, app/controllers/sessions_controller.rb:1,
    app/views/ops/admin/index.html.erb:26.
- Generated asset upload toggle (for screenshots)
  - Key: `AppSetting[:generated_image_upload]` (default true in production).
  - Refs: app/services/screenshots/capture_card_service.rb:140.
- User uploads enabled (UI)
  - Key: `AppSetting[:user_uploads_enabled]` (default true).
  - Refs: app/views/my_profiles/settings.html.erb:270.
- Proposed migration (next PR):
  - Eligibility gate: `REQUIRE_PROFILE_ELIGIBILITY` → `AppSetting[:require_profile_eligibility]`
    (default true).

Per‑environment Rails config (`config/environments/*.rb`)

- Active Storage service selector: `ACTIVE_STORAGE_SERVICE`
  - Keep as env (genuine per‑environment), or hardcode per env.
  - Refs: config/environments/production.rb:25.
- Force SSL override: `DISABLE_FORCE_SSL`
  - Keep as rare escape valve.
  - Refs: config/environments/production.rb:31.
- Hostname for URL generation: `APP_HOST`
  - Prefer `AppHost.current`/environment config; env ok as fallback.
  - Refs: config/environments/production.rb:66, various services.
- Logging/version markers: `APP_VERSION`, `GIT_SHA`
  - Fine as env injected at build/deploy.
  - Refs: config/initializers/structured_logging.rb:18.

Build/Deploy/Dev convenience (env is fine)

- `WEB_HOSTS`, `KAMAL_REGISTRY_PASSWORD`, `MISSION_CONTROL_JOBS_HTTP_BASIC`, `CI`, `BRAKEMAN_*`
  - Refs: README.md, bin/brakeman, config/routes.rb: mount guard.
- Image optimization tuning: `IMAGE_OPT_VIPS`, `IMAGE_OPT_BG_THRESHOLD`
  - OK as env; can move to AppSetting if you want runtime control.
  - Refs: Dockerfile:62, docs/image-optimization.md, app/services/images/optimize_service.rb:61.
- Active Storage backend override `ACTIVE_STORAGE_SERVICE`
  - Now superseded by `AppSetting[:generated_image_upload]`; env kept as fallback only.
- (Removed) Motifs bootstrap env: these were tied to motif generators that no longer exist.
- Rake/script helpers: `UPLOAD`, `SMOKE_LOGIN`
  - Limited to task context; safe to leave in env for ad‑hoc runs.

## Actionable Plan

- Short term
  - Stop adding new behavior flags to `.env`.
  - Use `AppSetting` + Ops for all runtime behavior/cost gates.
  - Keep secrets in credentials; avoid duplicating sensitive values in `.env`.
- Next PR
  - Migrate `SUBMISSION_MANUAL_INPUTS_ENABLED` and `REQUIRE_PROFILE_ELIGIBILITY` to DB toggles with
    Ops UI.
  - Optionally move `IMAGE_OPT_*` to AppSetting if you want runtime tuning in Ops.

## TL;DR

- `.env` is for local overrides only.
- Secrets in encrypted credentials.
- True per‑environment differences in `config/environments/*.rb`.
- Durable feature/cost gates in the DB via `AppSetting` and Ops.
