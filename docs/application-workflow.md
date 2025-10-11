Application Workflow Overview

High-level flow

- GitHub login creates a local User
  - `/auth/github` → OAuth callback exchanges code, fetches the authenticated user, and upserts a
    `User` with encrypted access token.
- Profiles sync from GitHub on-demand
  - `Profiles::SyncFromGithub` populates `Profile` and associations (repos, orgs, languages, social
    accounts, activity, README) and downloads avatar to `public/avatars`.
- Card generation and assets
  - `Profiles::SynthesizeCardService` computes card attributes from signals and persists
    `ProfileCard`.
  - `Gemini::AvatarImageSuiteService` generates avatar variants (1x1, 16x9, 3x1, 9x16); optionally
    uploads via Active Storage.
  - `Screenshots::CaptureCardService` renders fixed-size routes and captures PNGs (OG/Card/Simple).
- Storage and URLs
  - Test/dev use local disk; production uses DigitalOcean Spaces via Active Storage
    (`config/storage.yml`), returning public URLs.
  - `ProfileAssets::RecordService` records local paths and/or public URLs for each asset.
- Presentation
  - HTML: `/profiles/:username` shows profile summary, repos, orgs, activity, README.
  - JSON: `/profiles/:username.json` returns the same structured data.

Asynchronous orchestration

- Solid Queue configured in all environments.
- Jobs:
  - `Profiles::RefreshJob` refreshes a profile’s GitHub data.
  - `Screenshots::CaptureCardJob` captures OG/Card/Simple and records assets.
- Pipeline service:
  - `Profiles::GeneratePipelineService` orchestrates sync → avatar images → card synth → screenshots
    → optimize; can be wrapped in a job for full async execution (recommended).

Eligibility and limits

- Eligibility scoring:
  - `Eligibility::GithubProfileScoreService` computes a 0..N signal score with a configurable
    threshold.
  - `Gemini::AvatarImageSuiteService` supports `require_profile_eligibility` (off by default). We
    plan to enforce gating in the pipeline/job.
- Ownership and limits:
  - Users and Profiles are not yet linked; a “My Profiles” ownership model is planned (see
    `docs/auth-and-ownership.md`).
  - A per-user profile limit (e.g., 5) will be enforced when ownership is implemented.

Uploads

- Generated images/screenshots:
  - Upload when `GENERATED_IMAGE_UPLOAD` is truthy ("1", "true", "yes") or in production.
  - Service: `Storage::ActiveStorageUploadService` → returns `public_url` for DO Spaces/CDN.
- Avatar images:
  - Currently downloaded to `public/avatars/<login>.*` for local serving.
  - Future: upload avatars via Active Storage and persist URLs in `ProfileAssets` for uniform
    handling.

Feature flags and paid features

- Existing flags:
  - `GENERATED_IMAGE_UPLOAD` toggles uploads.
  - Provider selection via env/params in Gemini services.
- Paid features:
  - Stripe not yet integrated; recommended to guard with `STRIPE_ENABLED=1` and a basic entitlement
    model when added.

References

- Auth and ownership: `docs/auth-and-ownership.md`
- Screenshots driver ADR: `docs/adr/0002-screenshots-driver-puppeteer-node.md`
- OG images and routes: `docs/og-images.md`
- Testing overview: `docs/testing.md`
