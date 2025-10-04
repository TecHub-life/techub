# TecHub

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

   This runs `bundle check`, installs npm packages, prepares the application + Solid Queue databases, and clears temp files.

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
  with GitHub.
- `RESEND_API_KEY` reserved for future email notifications.

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
  private_key_path: techub-life.2025-10-02.private-key.pem

active_record_encryption:
  primary_key: <%= `openssl rand -hex 32`.strip %>
  deterministic_key: <%= `openssl rand -hex 32`.strip %>
  key_derivation_salt: <%= `openssl rand -hex 32`.strip %>
```

`.env` overrides still work for local experiments or CI providers that inject secrets as environment
variables. The test suite falls back to deterministic dummy encryption keys so it runs out of the
box.

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

## Additional Docs

- `docs/marketing-overview.md` preserves the pre-Rails marketing write-up.
- `docs/roadmap.md` tracks upcoming milestones so we can thin-slice future work.
- `components/` and `pages/` contain early ideation notes.

Questions? Drop an issue or DM @loftwah. Happy shipping!
