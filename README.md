# TecHub

[![CI](https://github.com/loftwah/techub/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/loftwah/techub/actions/workflows/ci.yml?query=branch%3Amain)
[![CodeQL](https://github.com/loftwah/techub/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/loftwah/techub/actions/workflows/codeql.yml?query=branch%3Amain)

```
   _____                   _  _            _
  |_   _|   ___     __    | || |   _  _   | |__
    | |    / -_)   / _|   | __ |  | +| |  | '_ \
  _|_|_   \___|   \__|_  |_||_|   \_,_|  |_.__/
_|"""""|_|"""""|_|"""""|_|"""""|_|"""""|_|"""""|
"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'
```

[techub.life](https://techub.life) — AI-powered trading cards for GitHub profiles.

Rails 8 application powering AI-assisted trading cards for GitHub profiles. It bundles the GitHub
App + OAuth flows, Solid Queue scheduling, Tailwind UI, and Kamal deployment so the whole experience
stays operable from a laptop.

## Stack Highlights

- **Rails 8 + SQLite** for a portable core with Solid Cache / Solid Queue / Solid Cable baked in.
- **Tailwind v4** with light/dark theming, sticky header, and marketing-ready landing page.
- **Composable services**: every integration returns `ServiceResult` objects for predictable
  success/failure handling.
- **GitHub integrations** covering App authentication, user-to-server OAuth, webhook ingestion, and
  profile summarisation.
- **Kamal** ready for containerised deploys with separate web + job hosts and SQLite volume.
- **Local developer CI** via `bin/ci`, wiring Rubocop, Prettier, and the Rails test suite together.

## Getting Started

1. Install dependencies the Rails way:

   ```bash
   bin/setup --skip-server
   ```

   This runs `bundle check`, installs npm packages, prepares the application + Solid Queue
   databases, and clears temp files.

Created by **Jared Hooker ([@GameDevJared89](https://x.com/GameDevJared89))** and **Dean Lofts
([@loftwah](https://x.com/loftwah))**.

2. Boot the full stack (web, CSS watcher, Solid Queue workers, recurring scheduler):

   ```bash
   bin/dev
   ```

3. Verify everything with the local CI pipeline:
   ```bash
   bin/ci
   ```

### Ruby Version Management (mise recommended)

- We recommend using `mise` to manage tool versions across languages. This repo includes `.ruby-version` and works seamlessly with `mise`.
- If you prefer `rbenv`, that also works fine. Ensure your Ruby matches `.ruby-version`.

Setup examples:

```bash
# Using mise (recommended)
curl https://mise.jdx.dev/install.sh | sh
mise use -g ruby@$(cat .ruby-version)
mise install

# Using rbenv
rbenv install -s $(cat .ruby-version)
rbenv local $(cat .ruby-version)
bundle install
```

## Docs Map

- Backups (Ops): docs/ops-backups.md
- Ops Runbook: docs/ops-runbook.md
- Storage: docs/storage.md
- Third‑Party Integrations: docs/integrations.md
- CI / CD: docs/ci-cd.md
- Ops Admin: docs/ops-admin.md
- AppSec Overview: docs/appsec-ops-overview.md
- Observability (Axiom/OTEL): docs/observability/axiom-opentelemetry.md
- Image Optimization: docs/image-optimization.md
- OG Images: docs/og-images.md
- Smoke Checklist: docs/smoke-checklist.md
- ADR Index: docs/adr-index.md
- Contributing: CONTRIBUTING.md

## Environment Variables

Copy `.env.example` to `.env` and fill in the values. Key settings:

- `GITHUB_APP_ID`, `GITHUB_PRIVATE_KEY` or `GITHUB_PRIVATE_KEY_PATH`, and `GITHUB_INSTALLATION_ID`
  for App-based API access.
- `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` for user OAuth.
- `GITHUB_WEBHOOK_SECRET` to verify incoming webhook signatures.
- `GITHUB_CALLBACK_URL_DEV` / `GITHUB_CALLBACK_URL_PROD` describe the redirect URLs you register
  with GitHub. Set the dev value to your actual forwarded host (for example
  `http://127.0.0.1:3000/auth/github/callback` or the Codespaces URL) so OAuth redirects match the
  GitHub App settings.
- `RESEND_API_KEY` reserved for future email notifications.
- `REQUIRE_PROFILE_ELIGIBILITY` (default ON): set to `0`/`false`/`no` to disable the eligibility
  gate (e.g., paid mode). Otherwise, gating is enforced.
- `SUBMISSION_MANUAL_INPUTS_ENABLED` — deprecated; manual inputs are always enabled and fail-safe.
  (URL + repos) pre-steps.
- `GENERATED_IMAGE_UPLOAD`: when set to `1`/`true`/`yes`, generated assets are uploaded to Active
  Storage (DigitalOcean Spaces in production) and public URLs recorded alongside local paths.
- `ASSET_REDIRECT_ALLOWED_HOSTS`: comma-separated hostnames allowed for off-host redirects to
  uploaded asset URLs (e.g., your CDN or Spaces endpoint). If unset, the app serves local copies
  when available and does not redirect to external hosts.
- `IMAGE_OPT_BG_THRESHOLD`: minimum file size in bytes to trigger background image optimization.
  Defaults to `300000` (≈300KB). Smaller files get a quick inline pass; larger files are optimized
  via a Solid Queue job on the `images` queue and optionally re-uploaded.

The PEM dropped in the repo (`techub-life.2025-10-02.private-key.pem`) can be referenced via
`GITHUB_PRIVATE_KEY_PATH` locally.

### Secrets & Encryption

Rails 8 expects long-lived secrets to live in `config/credentials.yml.enc`. Run
`bin/rails credentials:edit` and add a `github` block alongside your Active Record encryption keys,
for example:

- `EDITOR="cursor --wait" bin/rails credentials:edit`

```yaml
github:
  app_id: 123456
  client_id: your-oauth-client-id
  client_secret: your-oauth-client-secret
  private_key: |
    -----BEGIN RSA PRIVATE KEY-----
    paste-your-app-private-key-here
    -----END RSA PRIVATE KEY-----
  installation_id: your-installation-id

active_record_encryption:
  primary_key: <%= `openssl rand -hex 32`.strip %>
  deterministic_key: <%= `openssl rand -hex 32`.strip %>
  key_derivation_salt: <%= `openssl rand -hex 32`.strip %>
```

`.env` overrides still work for local experiments or CI providers that inject secrets as environment
variables. The test suite falls back to deterministic dummy encryption keys so it runs out of the
box.

The installation id comes from the GitHub UI (`https://github.com/settings/installations/<id>`). Set
it explicitly in credentials (`github.installation_id`) or via `GITHUB_INSTALLATION_ID`. There is no
auto-discovery or admin override; this value must be correct and stable. If you would rather point
at a file than paste the key, use the optional `GITHUB_PRIVATE_KEY_PATH` environment variable.

## GitHub App & OAuth Flow

- `Github::AppAuthenticationService` crafts the JWT needed for App authentication.
- `Github::AppClientService` issues installation tokens so we can talk to the API as the app.
- `Github::UserOauthService` exchanges OAuth codes, while `Github::FetchAuthenticatedUser` retrieves
  the authenticated user profile.
- `Users::UpsertFromGithub` persists encrypted access tokens and profile info. Sessions are plain
  Rails cookies.

Login starts at `/auth/github`, validates the OAuth `state`, and stores the user id in session on
return. GitHub webhooks post to `/github/webhooks`; signatures are checked before dispatching events
onto Solid Queue.

## Background Jobs & Scheduling

- `Profiles::RefreshJob` and `Profiles::SyncFromGithub` refresh profile cards via Solid Queue.
- `config/recurring.yml` schedules a refresh for `loftwah` every 30 minutes in all environments.
- `Github::WorkflowRunHandlerJob` is wired for webhook-driven reactions (currently logs payload
  metadata).

Heavy image optimization runs on the `images` queue. The job emits structured logs for visibility:
`image_optimize_started`, `image_optimize_skipped`, `image_optimize_completed`, and
`image_optimize_failed`, including duration and size-savings metrics.

Run workers locally via the `jobs` and `recurring` processes inside `Procfile.dev`.

## UI & Theming

- Tailwind v4 powers the styling with a dark-mode Stimulus controller (`theme_controller.js`).
- Header + footer partials add navigation, theme switcher, and GitHub auth entry points.
- The home page renders Loftwah’s profile summary, top repositories, and marketing copy pulled from
  service objects or the `Profile` model cache.

## Service Result Pattern

All services inherit from `ApplicationService` and return an instance of `ServiceResult`. This keeps
controller and job code honest—no nil checks, a consistent `success?` / `failure?` API, and
easy-to-test behaviour. See `test/services/` for examples.

## Tooling

- **Rubocop** via `bin/rubocop` (omakase config).
- **Prettier** (`npm run prettier:check` / `npm run prettier:write`) with Tailwind and XML plugins
  plus a repo-wide ignore file.
- **Brakeman** available via `bin/brakeman` for security audits.

`bin/ci` orchestrates the full lint + test pipeline so you can ship green builds before asking
GitHub for CI.

## Deployment With Kamal

The Kamal config is IP-free and single-node friendly:

- `servers.web.hosts` reads from `WEB_HOSTS` (defaults to `techub.life`).
- `servers.job.hosts` defaults to `WEB_HOSTS` (jobs run on the same host).
- Image publishes to `ghcr.io/techub-life/techub` (GHCR).
- Proxy host defaults to `techub.life`.

### Single-node quickstart (no IPs in repo)

1. Create an SSH host alias (example):

```
Host techub-do
  HostName <your-server-ip>
  User <your-ssh-user>
  IdentityFile ~/.ssh/<your-key>
```

2. Export the only two env vars you need:

```bash
export WEB_HOSTS="techub-do"            # your SSH alias
export KAMAL_REGISTRY_PASSWORD="<ghcr_token>"  # packages:write scope
```

3. Deploy:

```bash
bin/kamal setup
bin/kamal deploy
```

Notes:

- `JOB_HOSTS` is not needed; it defaults to `WEB_HOSTS`.
- `REGISTRY_USERNAME` defaults to the maintainer account; override if pushing from a different user.
- `.kamal/secrets` only references `KAMAL_REGISTRY_PASSWORD` and reads `RAILS_MASTER_KEY` from
  `config/master.key`.

### Production Smoke Checks

Run these on your server after deploy to validate storage and screenshots end‑to‑end:

```bash
kamal app exec -i web -- bin/rails runner 'puts({app_host: (defined?(AppHost) ? AppHost.current : nil), svc: Rails.configuration.active_storage.service}.inspect)'
kamal app exec -i web -- bin/rails runner 'puts ActiveStorage::Blob.services.fetch(Rails.configuration.active_storage.service).inspect'
kamal app exec -i web -- bin/rails runner 'b=ActiveStorage::Blob.create_and_upload!(io: StringIO.new("hi"), filename:"probe.txt"); puts b.url'
kamal app exec -i worker -- bin/rails "profiles:pipeline[loftwah,$(bin/rails runner 'print AppHost.current')]"
kamal app exec -i web -- bin/rails runner 'p Profile.for_login("loftwah").first.profile_assets.order(:created_at).pluck(:kind,:public_url,:local_path)'
```

## Docker Compose (Local)

Spin up web + worker locally using Docker Compose:

```bash
docker compose up --build
```

- Web: http://localhost:3000
- Worker: Solid Queue worker logs in the `worker` service
- Health: `/up`, `/ops/jobs` (if Mission Control is present)

See `docs/ops-runbook.md` for operations details.

### Manual Smoke Test

After Compose is up, you can run a minimal smoke inside the `web` container that validates Rails
health and screenshots without external APIs:

```bash
docker compose exec -T web bash -lc "APP_HOST=http://localhost:3000 SMOKE_LOGIN=smoketest script/smoke_web.sh"
```

What it does:

- Waits for `GET /up` to be healthy
- Seeds a dummy Profile offline (no GitHub calls)
- Captures an OG image via Puppeteer/Chromium to `tmp/smoke-og.png`

Inspect the output file if desired:

```bash
docker compose exec -T web ls -lah /rails/tmp/smoke-og.png
```

### Local production-mode assumptions (Compose)

- Compose is used only for local production-mode smoke testing; real deployments use Kamal.
- We bypass cloud dependencies locally:
  - `ACTIVE_STORAGE_SERVICE=local`
  - `DISABLE_FORCE_SSL=1`
- Rails credentials are provided by your local `config/master.key` mounted into the containers.
  - Ensure `config/master.key` exists (generated by `bin/rails credentials:edit`).
  - Compose also accepts `RAILS_MASTER_KEY` from your shell env as an alternative.
- Do not commit `config/master.key` to git.

## Additional Docs

- `docs/marketing-overview.md` preserves the pre-Rails marketing write-up.
- `docs/roadmap.md` tracks upcoming milestones so we can thin-slice future work.
- `docs/development-workflow.md` captures our “one feature per PR” and `ServiceResult` conventions.
- `docs/application-workflow.md` describes the end-to-end app flow (auth, sync, AI, screenshots,
  storage) and async orchestration.
- `docs/user-journey.md` is the authoritative end-to-end user journey (auth → submit → generate).
- `docs/submit-manual-inputs-workflow.md` documents the submit flow for manual inputs (URL + repos)
  end-to-end (spec-first; implementation partially scaffolded).
- `docs/status-dashboard.md` shows current implementation status per module.
- `docs/debugging-guide.md` explains how to pinpoint issues across stages and where artifacts live.
- `docs/ops-admin.md` documents ops and job administration (access, credentials, and common tasks).
- `docs/email.md` documents email (Resend) setup, zsh-friendly smoke tests, and ops auth.
- `docs/definition-of-done.md` shows how we write DoD and examples of “what good looks like”.
- `docs/eligibility-policy.md` details the default-on eligibility policy (signals, scoring,
  override).
- `components/` and `pages/` contain early ideation notes.

Questions? Drop an issue or DM @loftwah. Happy shipping!
