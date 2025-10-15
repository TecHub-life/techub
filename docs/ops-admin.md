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
