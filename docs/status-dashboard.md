# Implementation Status Dashboard

Authoritative status across the end-to-end journey. Links point to code and docs for quick
drill‑downs.

Legend: [Done], [Partial], [Planned]

Authentication & Accounts

- [Done] GitHub OAuth sign-in (`/auth/github`) → `Users::UpsertFromGithub`
- [Done] My Profiles ownership (User ↔ Profile link + per-user cap; list/remove UI)
- [Done] Per-user notifications (email + preference; deduped outbox)

Submission & Eligibility

- [Done] Submit controller + form (capture `login`, optional URL + repos)
- [Done] Eligibility scoring service: `Eligibility::GithubProfileScoreService`
- [Done] Enforce eligibility gate in pipeline/job (default ON; surfaced on failure)

Manual Inputs (URL + Repos)

- [Done] DB field: `profiles.submitted_scrape_url`
- [Done] Preserve `submitted` repos in sync; `ProfileRepository.repository_type` includes
  `submitted`
- [Done] Ingest service for submitted repos: `Profiles::IngestSubmittedRepositoriesService`
- [Done] Scraper service with caps: `Scraping::ScrapeUrlService` (+ tests)
- [Done] Persistence of scraped content: `ProfileScrape` + `Profiles::RecordSubmittedScrapeService`
  (+ tests)
- [Done] Pipeline pre-steps wired (flag‑gated) for scrape + repo ingest

GitHub Ingestion

- [Done] `Profiles::SyncFromGithub` (repos, orgs, languages, social, activity, README, avatar)
- [Done] Topic recording for repos; active/pinned/top categorization

Card Synthesis & Media

- [Done] `Profiles::SynthesizeCardService` → `ProfileCard`
- [Done] Avatar images via Gemini (`Gemini::AvatarImageSuiteService`); artifacts recorded
- [Done] Screenshots via Puppeteer (`Screenshots::CaptureCardService`) + background job
- [Done] Image optimization service (inline in pipeline); optional upload to Spaces/S3
  (`Storage::ActiveStorageUploadService`)

Observability & Debuggability

- [Done] Prompts + metadata artifacts saved under `public/generated/<login>/meta` (PR 03)
- [Partial] Mission Control jobs UI (mount present; polish + docs pending)
- [Partial] Eligibility and pipeline status surfaced in UI (basic badge; enrich reasons)

Docs (single sources of truth)

- [Done] User journey: `docs/user-journey.md`
- [Done] Manual inputs workflow: `docs/submit-manual-inputs-workflow.md`
- [Done] Scraping driver ADR: `docs/adr/0004-scraping-driver.md`
- [Done] Submit manual inputs ADR: `docs/adr/0003-submit-manual-inputs.md`

Outstanding Wiring (next milestones)

- My Profiles page (list/remove) + ownership management UI
- Retry/backoff strategy and metrics for pipeline + screenshot jobs
- Enrich eligibility decline messaging in UI (signals)
- Mission Control visibility for pipeline stages and failures
- Optional: move image optimization to a background job for larger assets
