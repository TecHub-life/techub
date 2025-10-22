# Ops Runbook: Pipeline Status and Notifications

## Status semantics

- success: All enabled stages completed. Owners receive a “completed” email (deliver-once per
  profile).
- partial_success: Completed with fallbacks (e.g., AI traits fallback). Owners are not emailed; Ops
  receives an alert.
- failure: Pipeline failed. Owners receive a “failed” email; Ops receives an alert.

Notes:

- When AI artwork or AI image descriptions are disabled by policy, the pipeline does not mark
  partial. That configuration is treated as expected, not degraded.
- Partial is reserved for genuine degradations (e.g., AI traits fell back to heuristics).

## Email + Alerts

- Owners:
  - success → ProfilePipelineMailer.completed (deliver_later, deduped per profile/event)
  - failure → ProfilePipelineMailer.failed (deliver_later, deduped per profile/event)
  - partial → no owner email
- Ops:
  - partial → OpsAlertMailer.job_failed with metadata indicating partial
  - failure → OpsAlertMailer.job_failed with error message and metadata

## Resend setup

- credentials: `resend.api_key`
- env: delivery_method `:resend` (production/development)
- smoke test: `bin/rake "email:smoke[to@example.com,Hello]"`

# Ops Runbook

Practical steps to run, monitor, and debug TecHub locally and in prod.

## Local (Compose)

- Requirements: Docker, docker compose
- Start services:

  ```bash
  docker compose up --build
  ```

- App: http://localhost:3000
- Worker: Solid Queue worker logs in the `worker` container.
- First run seeds and create DB inside a container if needed:

  ```bash
  docker compose exec web bin/rails db:prepare
  ```

## Jobs Visibility

- Mission Control (when gem is present): `/ops/jobs`
- Protect with `MISSION_CONTROL_JOBS_HTTP_BASIC` if desired (see config/routes.rb)

## Healthchecks

- HTTP: `/up` (Rails)
- Gemini: `/up/gemini` and `/up/gemini/image`

### Gemini providers

- Provider resolution precedence: credentials `gemini.provider` > env `GEMINI_PROVIDER` > inference
- Images-specific override: env `GEMINI_IMAGES_PROVIDER` (e.g., set to `ai_studio` to force images
  only)
- Auto-fallback: when Vertex image requests return 400 field violations, service will retry via AI
  Studio and log provider used

Verify in console:

```ruby
Gemini::Configuration.provider
Gemini::ImageGenerationHealthcheckService.call
Gemini::AvatarImageSuiteService.call(login: "loftwah")
```

## Pipelines

- Submit at `/submit` (auth required). This enqueues `Profiles::GeneratePipelineJob` and marks
  status on the profile.
- Status surfaces on the profile page and in `/my/profiles`.
- Artifacts: `public/generated/<login>/` (PNG + meta); optional upload to Spaces/S3.

## Notifications

- Per-user email & preference (default ON). Settings at `/settings/account`.
- Deduped by `NotificationDelivery` (no duplicate emails per event/subject).

## Logs & Retries

- Pipeline and screenshot jobs have exponential backoff and structured logs
  - `pipeline_started` / `pipeline_completed` / `pipeline_failed`
  - `screenshot_failed` / `record_asset_ok`

## Image optimization

- Default: libvips via `image_processing` (fast, low memory). Fallback to ImageMagick.
- Build: ImageMagick 7 installed from source; `magick -version` verified at build time.
- Runtime flags:
  - `IMAGE_OPT_VIPS=1` (default in Dockerfile) to use vips
  - `IM_CLI=magick` or `IM_CLI=convert` to force a specific CLI
- See `docs/image-optimization.md` for policy and troubleshooting.

## Common Tasks

- Run tests:

  ```bash
  PARALLEL_WORKERS=1 bin/rails test
  ```

- Capture screenshots manually:

  ```bash
  rake screenshots:capture[login,og]
  ```

- Capture all three variants if missing (idempotent):

  ```bash
  rake screenshots:capture_all[login]
  ```

## Production (Kamal)

- See `config/deploy.yml` and `README.md` for Kamal deployment. Provide credentials in
  `.kamal/secrets` and run:

  ```bash
  bin/kamal setup
  bin/kamal deploy
  ```

### Storage & Screenshots (Quick Checks)

Run these after a deploy to validate credentials, storage, and screenshots:

```bash
# Host and storage service
kamal app exec -i web -- bin/rails runner 'puts({app_host: (defined?(AppHost) ? AppHost.current : nil), svc: Rails.configuration.active_storage.service}.inspect)'
kamal app exec -i web -- bin/rails runner 'puts ActiveStorage::Blob.services.fetch(Rails.configuration.active_storage.service).inspect'

# Upload probe
kamal app exec -i web -- bin/rails runner 'b=ActiveStorage::Blob.create_and_upload!(io: StringIO.new("hi"), filename:"probe.txt"); puts b.url'

# Full pipeline for a user
kamal app exec -i worker -- bin/rails "profiles:pipeline[loftwah,$(bin/rails runner 'print AppHost.current')]"

# Asset records
kamal app exec -i web -- bin/rails runner 'p Profile.for_login("loftwah").first.profile_assets.order(:created_at).pluck(:kind,:public_url,:local_path)'
```

See `docs/storage.md` for detailed troubleshooting.
