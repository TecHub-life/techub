# Database Backups (Ops)

This app includes a simple, dependency‑free backup system for SQLite files stored in `storage/`,
with daily automated uploads to object storage (S3‑compatible), pruning by age, and safe restore
helpers.

It is designed to “just work” unattended in production once the environment is configured. Use the
Ops panel or rake tasks for manual runs or restore/migration workflows.

## What Gets Backed Up

- All `.sqlite3` files under `storage/`
- Uploaded to `$BACKUP_BUCKET/$BACKUP_PREFIX/$RAILS_ENV/$TIMESTAMP/filename.sqlite3` (DigitalOcean
  Spaces / S3‑compatible)
- Each backup run creates a new timestamped group (e.g., `20251020-021500`)

## Configuration

Set these environment variables in production (e.g., with Kamal secrets/env):

- `BACKUP_BUCKET` (optional): backup bucket name; if unset, falls back to `DO_SPACES_BACKUP_BUCKET`
  or `DO_SPACES_BUCKET`
- `BACKUP_PREFIX` (optional, default `db_backups`): path prefix in bucket
- DigitalOcean Spaces env (used if present): `DO_SPACES_ACCESS_KEY_ID`,
  `DO_SPACES_SECRET_ACCESS_KEY`, `DO_SPACES_REGION`, `DO_SPACES_ENDPOINT`, `DO_SPACES_BUCKET`
- `BACKUP_RETENTION_DAYS` (optional, default `14`): delete groups older than N days
- `BACKUP_KEEP_MIN` (optional, default `7`): always keep at least N recent groups
- Standard AWS credentials and region must be present (e.g., `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`). If using an S3‑compatible service, configure the AWS SDK
  endpoint via your environment or instance profile.

Sample entries are in `.env.example`.

## Scheduling

- Daily backup at `02:00` and prune at `02:10` are configured in `config/recurring.yml`
- Recurring execution is handled by Solid Queue (see `config/puma.rb` using `plugin :solid_queue`
  when `SOLID_QUEUE_IN_PUMA=true`)

## Ops Panel

- Path: `/ops` (HTTP Basic protected in production)
- Card: “Database Backups” with buttons:
  - “Create Backup” → Immediate upload of `storage/*.sqlite3`
  - “Prune Old” → Applies retention policy and minimum keep

## Rake Tasks (manual)

- Create: `bin/rails db:backup:create`
- Prune: `bin/rails db:backup:prune`
- Restore (dev or explicitly allowed):
  - Latest: `CONFIRM=YES bin/rails db:backup:restore[latest]`
  - Specific group: `CONFIRM=YES bin/rails db:backup:restore[YYYYMMDD-HHMMSS]`

Restore is intentionally guarded:

- Allowed in development, or when `ALLOW_DB_RESTORE=1` is set
- Requires `CONFIRM=YES` env on invocation
- Files are restored to `storage/` (does not auto‑swap live DBs)

## Retention and Cleanup

- The prune job keeps at least `BACKUP_KEEP_MIN` groups, then deletes only groups older than
  `BACKUP_RETENTION_DAYS`.
- We recommend adding an S3 lifecycle policy as a secondary safeguard mirroring (or exceeding) the
  retention window.

Example lifecycle (keep 21 days) — apply in your S3 console/IaC:

```json
{
  "Rules": [
    {
      "ID": "db-backups-retain-21d",
      "Status": "Enabled",
      "Filter": { "Prefix": "db_backups/" },
      "Expiration": { "Days": 21 }
    }
  ]
}
```

## Operational Notes

- Backups run unattended once configured; operate the UI/tasks only for on‑demand backup, pruning,
  restores, or migrations.
- Consider encrypting the bucket and restricting IAM to write/read only the backup prefix.
- Backups are uploaded without compression by default to keep runtime simple and dependencies
  minimal. If storage becomes a concern, we can extend the service to gzip before upload.

## Components (for reference)

- Services: `Backups::CreateService`, `Backups::PruneService`, `Backups::RestoreService`
- Jobs: `Backups::CreateJob`, `Backups::PruneJob`
- UI: `/ops` → “Database Backups”
- Rake: `db:backup:create`, `db:backup:prune`, `db:backup:restore`
- Config: `config/recurring.yml`, `.env.example`
