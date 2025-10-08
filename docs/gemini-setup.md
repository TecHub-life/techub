### Gemini setup (Vertex-only)

1. Create/obtain a Vertex service account key (JSON).

2. Put values into encrypted credentials:

```yaml
google:
  project_id: techub-474511
  location: us-central1
  application_credentials_json: |
    { "type": "service_account", ... }
```

- Use `EDITOR="cursor --wait" bin/rails credentials:edit`.
- Paste the entire JSON as a single JSON string (do not break YAML quoting). Using `|` preserves
  newlines.

3. Local env for dev:

```bash
GEMINI_PROVIDER=vertex
GOOGLE_CLOUD_PROJECT=techub-474511
GEMINI_LOCATION=us-central1
# Optional AI Studio fallback (not used in prod)
# GEMINI_API_KEY=
# GEMINI_API_BASE=https://generativelanguage.googleapis.com/v1beta
```

4. Idiot-proof ways to paste SA JSON:

- Manual (safest):
  1. Run `EDITOR="cursor --wait" bin/rails credentials:edit`
  2. Under `google:`, add `application_credentials_json: |` and paste the entire JSON as a single
     line or multi-line block. Ensure it remains valid JSON.
- Scripted helper (from a JSON file at project root):
  - `ruby script/sa_json_to_yaml.rb techub-474511-xxxx.json`
  - Copy the output into the credentials editor under `google:`.

5. Alternative dev method (file on disk):

```bash
export GOOGLE_APPLICATION_CREDENTIALS=$PWD/techub-474511-xxxx.json
```

We still recommend using encrypted creds; the file path method is only for quick local tests.

6. Required roles/permissions for the service account:

- roles/aiplatform.user — display name: Vertex AI User (required)
- roles/serviceusage.serviceUsageConsumer — display name: Service Usage Consumer (required)
- Optional (logging/monitoring): roles/logging.logWriter, roles/monitoring.metricWriter

Notes:

- You do not need AI Platform Admin/Developer roles; those are legacy or overly broad for this use
  case.
- You also do not need Service Usage Admin unless you want the service account itself to
  enable/disable APIs.

7. Verify healthcheck:

8. Verify healthcheck:

```bash
curl -s http://localhost:3000/up/gemini
```

- 200 + `{ ok: true }` means config is good. 503 means auth or permissions issue.
