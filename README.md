# TecHub

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
- `SUBMISSION_MANUAL_INPUTS_ENABLED` (default OFF): set to `1`/`true`/`yes` to enable manual inputs
  (URL + repos) pre-steps.

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

The installation id comes from the GitHub UI (`https://github.com/settings/installations/<id>`);
store it in credentials as shown above or set `GITHUB_INSTALLATION_ID` in your `.env`. If you would
rather point at a file than paste the key, use the optional `GITHUB_PRIVATE_KEY_PATH` environment
variable.

## GitHub App & OAuth Flow

- `Github::AppAuthenticationService` crafts the JWT needed for App authentication.
- `Github::InstallationTokenService` + `Github::AppClientService` issue installation tokens so we
  can talk to the API as the app.
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

`config/deploy.yml` targets a `web` host and a dedicated `job` host. Update the IPs/usernames for
your infra, push the image to `ghcr.io/loftwah/techub`, and run:

```bash
bin/kamal setup
bin/kamal deploy
```

Secrets live in `.kamal/secrets`; populate them via environment variables or your password manager
(never check plaintext credentials into git).

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
- `docs/definition-of-done.md` shows how we write DoD and examples of “what good looks like”.
- `docs/eligibility-policy.md` details the default-on eligibility policy (signals, scoring,
  override).
- `components/` and `pages/` contain early ideation notes.

Questions? Drop an issue or DM @loftwah. Happy shipping!
