# Implementation Status Dashboard

Authoritative status across the end-to-end journey. Links point to code and docs for quick
drill‑downs.

Legend: [Done], [Partial], [Planned]

Authentication & Accounts

- [Done] GitHub OAuth sign-in (`/auth/github`) → `Users::UpsertFromGithub`
- [Planned] My Profiles ownership (link User ↔ Profile) and per-user limits

Submission & Eligibility

- [Planned] Submit controller + form (capture `login`, optional URL + repos)
- [Done] Eligibility scoring service: `Eligibility::GithubProfileScoreService`
- [Planned] Enforce eligibility gate in pipeline/job (roadmap PR 14)

Manual Inputs (URL + Repos)

- [Done] DB field: `profiles.submitted_scrape_url`
- [Done] Preserve `submitted` repos in sync; `ProfileRepository.repository_type` includes
  `submitted`
- [Done] Ingest service for submitted repos: `Profiles::IngestSubmittedRepositoriesService`
- [Done] Scraper service with caps: `Scraping::ScrapeUrlService` (+ tests)
- [Done] Persistence of scraped content: `ProfileScrape` + `Profiles::RecordSubmittedScrapeService`
  (+ tests)
- [Partial] Pipeline pre-steps: scrape recorded; repo ingest not yet wired; needs flag‑gate

GitHub Ingestion

- [Done] `Profiles::SyncFromGithub` (repos, orgs, languages, social, activity, README, avatar)
- [Done] Topic recording for repos; active/pinned/top categorization

Card Synthesis & Media

- [Done] `Profiles::SynthesizeCardService` → `ProfileCard`
- [Done] Avatar images via Gemini (`Gemini::AvatarImageSuiteService`); artifacts recorded
- [Done] Screenshots via Puppeteer (`Screenshots::CaptureCardService`); background job scaffold
- [Done] Image optimization service; optional upload to Spaces/S3
  (`Storage::ActiveStorageUploadService`)

Observability & Debuggability

- [Done] Prompts + metadata artifacts saved under `public/generated/<login>/meta` (PR 03)
- [Partial] Mission Control jobs UI (roadmap PR 06)
- [Partial] Eligibility and pipeline status surfaced in UI

Docs (single sources of truth)

- [Done] User journey: `docs/user-journey.md`
- [Done] Manual inputs workflow: `docs/submit-manual-inputs-workflow.md`
- [Done] Scraping driver ADR: `docs/adr/0004-scraping-driver.md`
- [Done] Submit manual inputs ADR: `docs/adr/0003-submit-manual-inputs.md`

Outstanding Wiring (next milestones)

- Submit controller + form; store manual inputs
- Wire repo ingest step into pipeline (flag‑gated)
- Enforce eligibility gate in pipeline/job; surface decline reasons
- My Profiles (ownership + per-user limits)
- Mission Control visibility for pipeline stages and failures
