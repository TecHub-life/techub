# Ops Admin Guide

This guide explains how to access and administer background jobs and ops tools.

## Access

- Environment protections:
  - Development: available locally when `.env` defines `MISSION_CONTROL_JOBS_HTTP_BASIC`.
  - Production: mounted only if credentials exist in `config/credentials.yml.enc` at
    `mission_control.jobs.http_basic`.
- Authentication: HTTP Basic (same creds for `/ops` and `/ops/jobs`). Realm: "Mission Control".

## URLs

- `/ops` (recommended entry):
  - Unified panel under the site layout
  - Quick stats and shortcuts
  - Embedded Mission Control Jobs UI (with tabs)
  - "Open full screen" link to the full engine UI
- `/ops/jobs` (full Mission Control UI):
  - Queues view (pause/resume)
  - Jobs (running/failed/all)
  - Workers and recurring tasks

## Credentials

- Development (`.env`):
  - `MISSION_CONTROL_JOBS_HTTP_BASIC=user:password`
- Production (credentials):
  - `mission_control.jobs.http_basic: "user:password"`

## Operations

- Pause/resume queues: use the Queues view in `/ops/jobs`.
- Retry/discard jobs: open a job in `/ops/jobs` and use the action buttons.
- Recurring tasks: see Recurring; edit schedules in `config/recurring.yml` and redeploy.
- Workers/processes: ensure the jobs process is running.
  - Local: `bin/dev` (uses `Procfile.dev` → `jobs: bin/jobs start`)
  - Deploy: jobs run on the same host by default (see `Kamal` config).

## Logs

- Development: `/ops` shows a tail of `log/development.log` (best-effort).
- Production: logs go to STDOUT. For searchable prod logs, forward to Axiom (or similar) and link
  from `/ops`.

## Troubleshooting

- 404 on `/ops/jobs`: engine not mounted. In prod, ensure credentials exist; in dev, ensure the gem
  is installed.
  - Check: `bin/rails routes -g ops/jobs`
- 401 prompt loops: wrong HTTP Basic. Verify `.env` or credentials.
- No workers detected: confirm local `bin/dev` is running, or deployment jobs host is healthy.
- Solid Queue stats nil: ensure the queue DB is reachable; migrations are up to date.

## Security Notes

- Admin routes are private and behind HTTP Basic; do not share credentials.
- In production, the engine is not mounted unless credentials exist.

## Ownership Management

### Terminology

- Profile: a Techub profile (e.g. `@octocat`) representing a public GitHub account within Techub.
  Profiles are identified by `profiles.login`.
- User: an authenticated GitHub account in the system (OAuth). Users are identified by
  `users.login`.

There can be many `User`↔`Profile` links, but exactly one link per profile is marked as the owner.

- Manage ownerships at `/ops/ownerships` (HTTP Basic protected).
- UI:
  - Filter by profile with the selector at the top.
  - Table lists `Profile`, `User`, current `Owner` state, and `Actions`.
  - Actions:
    - Make owner: set this link as the single owner for the profile (removes other links for the
      profile).
    - Transfer: move ownership to another GitHub login by entering the target user login.
    - Remove link: delete a non-owner link. Owner links cannot be deleted; use Transfer.

### Invariants

- A profile must always have exactly one owner.
- You cannot clear or delete the owner link.
- To change owners, use Transfer (or Make owner on an existing non-owner link).
- Transfer semantics: setting a new owner removes all other links (including the previous owner and
  any non-owner links) to keep a single source of truth.
- Rake equivalents:
  - `rake techub:ownership:list`
  - `rake techub:ownership:list_profile[login]`
  - `rake techub:ownership:list_user[user_login]`
  - `rake techub:ownership:claim[user_login,profile_login]`
  - `rake techub:ownership:promote[ownership_id]`
  - `rake techub:ownership:demote[ownership_id]`
  - `rake techub:ownership:remove[ownership_id]`
  - `rake techub:ownership:set_owner[profile_login,user_login]`
