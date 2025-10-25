# Storage and URL Host

This doc explains how storage works across environments, how the URL host is resolved, and how to
smoke‑test and troubleshoot quickly.

## Environments

- Development
  - `config.active_storage.service = :local`
  - Files are written to `storage/` on disk.
  - Set `GENERATED_IMAGE_UPLOAD=1` to force services that normally upload (e.g., screenshots) to
    perform uploads. In dev, the generated `blob.url` points to the local Rails blob endpoint.

- Production
  - Defaults to `:do_spaces` (DigitalOcean Spaces, S3‑compatible) via `config/storage.yml`.
  - Credentials are the source of truth (`config/credentials.yml.enc`):
    - `do_spaces.endpoint`, `do_spaces.bucket_name`, `do_spaces.region`, `do_spaces.access_key_id`,
      `do_spaces.secret_access_key`
  - Do not set `ACTIVE_STORAGE_SERVICE=local` in production.

## URL Host Resolution

- We centralize host resolution in `AppHost.current`:
  - Prefers `Rails.application.credentials.dig(:app, :host)`
  - Falls back to `ENV["APP_HOST"]`
  - Defaults to `https://techub.life` in production and `http://127.0.0.1:3000` otherwise
- Production ActiveStorage URLs are pinned via:
  - `ActiveStorage::Current.url_options = { host: AppHost.current }`

See also: `docs/integrations.md` for DigitalOcean Spaces setup, CDN and CORS configuration, and
fallbacks if storage is not configured.

Recommended credentials:

```yaml
app:
  host: https://techub.life
do_spaces:
  # Use the REGION endpoint with path-style addressing (see config/storage.yml)
  endpoint: https://nyc3.digitaloceanspaces.com
  bucket_name: <bucket>
  region: <region>
  access_key_id: <key>
  secret_access_key: <secret>
  # Optional: custom CDN domain for canonical public URLs
  cdn_endpoint: https://assets.cdn.techub.life
```

## Quick Smokes (Production)

Use Kamal to exec into containers. Examples below assume a `web` and `worker` role.

- Verify host and storage service:

```bash
kamal app exec -i web -- bin/rails runner 'puts({app_host: (defined?(AppHost) ? AppHost.current : nil), svc: Rails.configuration.active_storage.service}.inspect)'
kamal app exec -i web -- bin/rails runner 'puts ActiveStorage::Blob.services.fetch(Rails.configuration.active_storage.service).inspect'
```

- Upload probe (prints a public URL) and HEAD it:

````bash
kamal app exec -i web -- bin/rails runner 'b=ActiveStorage::Blob.create_and_upload!(io: StringIO.new("hi"), filename:"probe.txt"); puts b.url'
kamal app exec -i web -- bash -lc 'curl -IfsS $(bin/rails runner "print ActiveStorage::Blob.last.url") | head -n1'

DNS quick check:

```bash
dig +short CNAME assets.cdn.techub.life
# expect: techub-life.nyc3.cdn.digitaloceanspaces.com.
````

````

- Run end‑to‑end pipeline for a user (screenshots use the credentials host):

```bash
kamal app exec -i worker -- bin/rails "profiles:pipeline[loftwah,$(bin/rails runner 'print AppHost.current')]"
````

- Check asset records:

```bash
kamal app exec -i web -- bin/rails runner 'p Profile.for_login("loftwah").first.profile_assets.order(:created_at).pluck(:kind,:public_url,:local_path)'
```

## Troubleshooting Map

- Upload probe fails (no URL/403)
  - Confirm credentials values and that service is `:do_spaces`.
  - Curl the URL; if 403, verify Spaces bucket policy/public ACL.

- "avatar_upload_skipped_missing_path"
  - The local file path was empty or missing; check disk space and ImageMagick.
  - To regenerate artwork, use the profile Settings UI (image regeneration is not exposed via rake
    to avoid accidental cost).

- Screenshots fail (connection refused/timeouts)
  - Ensure the URL uses `AppHost.current` and that the host is reachable from the worker.
  - For compose/local, point at the service hostname (e.g., `http://web`).

- No asset records
  - Run targeted captures (these record assets):
    - `bin/rails 'screenshots:capture[login,og,$(bin/rails runner "print AppHost.current")]'`

Artifacts:

- Events: `public/generated/<login>/meta/pipeline-events.jsonl`
- Report: `public/generated/<login>/meta/pipeline-report.json` (best effort)
