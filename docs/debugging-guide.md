# Debugging & Fault Isolation Guide

Goal: pinpoint failures quickly from “prompt is wrong” down to the exact stage and inputs.

Where to look by stage

- Eligibility
  - Service: `Eligibility::GithubProfileScoreService`
  - Inputs: profile payload, repositories (with pushed_at), pinned repos, README, organizations,
    recent events
  - Output: `score`, `signals` with reasons; log context included in failures

- GitHub Sync
  - Service: `Profiles::SyncFromGithub`
  - Inputs: Octokit client (user token optional → app client fallback)
  - Artifacts: DB rows updated (profiles, profile_repositories, profile_languages,
    profile_organizations, profile_social_accounts, profile_activities, profile_readmes)
  - Common faults: rate limits, bad tokens, unexpected GitHub payloads (see logs)

- Manual Repos
  - Service: `Profiles::IngestSubmittedRepositoriesService`
  - Inputs: up to 4 full names; Octokit app client
  - Artifacts: `profile_repositories` rows with `repository_type: submitted`; `repository_topics`
  - Faults: invalid names, 404, API errors; service logs warnings and continues

- Manual URL Scrape
  - Services: `Scraping::ScrapeUrlService` and `Profiles::RecordSubmittedScrapeService`
  - Inputs: URL; caps (2MB body, 10s timeouts, 3 redirects, HTML‑only); SSRF protections
  - Artifacts: `profile_scrapes` row with title, desc, canonical, text (≤20k), links (≤50),
    content_type, http_status, bytes
  - Faults: non‑HTML responses, timeouts, blocked hosts; errors carried in `ServiceResult`

- Prompting (Avatar images)
  - Service: `Gemini::AvatarImageSuiteService` (+ `AvatarPromptService`)
  - Artifacts: prompts + metadata saved under `public/generated/<login>/meta/` (per provider)
  - Faults: model errors, empty/fragmentary prompts, provider flakiness; check metadata JSON for
    inputs and finish reason

- Card Synthesis
  - Service: `Profiles::SynthesizeCardService`
  - Inputs: profile signals (repos, languages, activity, orgs, scraped content if used)
  - Artifacts: `profile_cards` row; logs on rule violations

- Screenshots
  - Service: `Screenshots::CaptureCardService` (Node); route renders
    `/cards/:login/(og|card|simple)`
  - Artifacts: PNGs in `public/generated/<login>/`
  - Faults: headless browser issues, viewport size mismatch; check Node script logs

- Uploads
  - Service: `Storage::ActiveStorageUploadService`
  - Artifacts: `profile_assets` rows with `public_url`
  - Faults: credential issues; check S3/Spaces responses

Quick Triage Steps

1. Confirm sync updated the profile (timestamps, repo counts)
2. Inspect `public/generated/<login>/meta/` for prompts + metadata
3. If manual URL given, inspect `profile_scrapes` row (content_type, http_status, bytes, text
   excerpt)
4. Check `profile_repositories` for `submitted` entries + topics
5. Review service logs by `service:` and `status:` fields (StructuredLogger)

Tests to run first

- `test/services/scraping/scrape_url_service_test.rb`
- `test/services/profiles/record_submitted_scrape_service_test.rb`
- `test/services/profiles/generate_pipeline_service_test.rb` (when added)

Notes

- All services use `ServiceResult`; do not rely on nil checks.
- Prefer artifacts and DB rows to reason about state; avoid guessing based on UI alone.
