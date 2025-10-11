Testing And Validation Overview

What the tests cover (at a glance)

- Workflow orchestration (Profiles::GeneratePipelineService)
  - Orchestrates: SyncFromGithub → AvatarImageSuiteService → SynthesizeCardService →
    CaptureCardService (OG/Card/Simple) → optional optimization.
  - Returns a single ServiceResult capturing images, screenshots, and card id.

- Card synthesis (Profiles::SynthesizeCardService)
  - Computes stats (0..100) from profile signals and persists ProfileCard.
  - Preview mode returns attributes without persisting.
- Screenshot capture (Screenshots::CaptureCardService)
  - Success path returns PNG output and metadata (width/height, mime type); test env avoids Node.
  - Failure path exercised by stubbing Rails.env and Kernel.system.
- Card routes and views
  - /cards/:login/(og|card|simple) render fixed-size frames (1200×630, 1280×720).
- Upload to cloud (ActiveStorage)
  - ActiveStorageUploadService returns a public URL (stubbed; no network).
  - Avatar image suite integration adds public_url when upload is enabled.
- Asset persistence (ProfileAssets::RecordService)
  - Upserts ProfileAsset rows (kind, mime, width/height, local_path, public_url).

  - `bin/rails test test/services/profiles/generate_pipeline_service_test.rb` How to run locally

- Full CI: `bin/ci`
- Parallelization: tests default to serial in CI. Locally, if you hit sandbox/DRb issues, run with
  `DISABLE_PARALLEL_TESTS=1 bin/rails test`.
- Specific tests:
  - `bin/rails test test/services/profiles/synthesize_card_service_test.rb`
  - `bin/rails test test/controllers/cards_controller_test.rb`
  - `bin/rails test test/services/screenshots/capture_card_service_test.rb`
  - `bin/rails test test/services/gemini/avatar_image_suite_service_upload_test.rb`
  - `bin/rails test test/services/storage/active_storage_upload_service_test.rb`

Manual verification flow

1. Generate AI artwork and write artifacts
   - `VERBOSE=1 bundle exec rake "gemini:avatar_generate:verify"`
2. Synthesize and persist a card
   - `bundle exec rake "profiles:card[loftwah]"`
3. Capture screenshots (OG/card/simple)
   - `APP_HOST=http://127.0.0.1:3000 bundle exec rake "screenshots:capture[loftwah,og]"`
   - Writes to `public/generated/<login>/` and records ProfileAsset; set `GENERATED_IMAGE_UPLOAD=1`
     to also upload.

Logging

- All services subclass `ApplicationService`, which logs JSON to STDOUT via `StructuredLogger` on
  both success and failure, with service name, status, error, and provided metadata.
- Screenshot capture logs include login, variant, width/height, local path, and public URL (if
  uploaded).
