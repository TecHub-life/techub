# End-to-End User Journey (Auth → Submit → Generate)

Status: Spec-first, authoritative overview

## 1) Arrive at TecHub

- Landing routes: `/` home, `/docs`, `/directory`, `/leaderboards`, `/submit` (marketing copy).
- No data required to browse public pages.

## 2) Sign in with GitHub

- Entry: “Sign in with GitHub” triggers `/auth/github`.
- OAuth callback exchanges code and stores a `User` with encrypted access token.
  - Services: `Github::UserOauthService`, `Github::FetchAuthenticatedUser`,
    `Users::UpsertFromGithub`.
- Session cookie holds user id. Logout clears session.

Result: You are an authenticated `User` and can manage submissions (planned: “My Profiles”).

## 3) Add a Profile (Submit)

Intent: You ask TecHub to generate a card for a GitHub username.

- Inputs:
  - `login` (GitHub username) — required
  - Manual inputs (optional; spec-first):
    - `submitted_scrape_url` (one URL to scrape for extra context)
    - `submitted_repositories[]` (up to 4 `owner/repo` full names)

## 4) Eligibility Gate (Cost control)

We only accept a submission if the GitHub account meets minimum open-source signals.

- Service: `Eligibility::GithubProfileScoreService` with signals:
  - Account age ≥ 60 days
  - Public repository activity in last 12 months (≥ 3 owned, non-archived repos pushed)
  - Social proof (followers OR following ≥ 3)
  - Meaningful profile (bio/README/pinned)
  - Recent public events (≥ 5 in last 90 days)
- Threshold: default 3/5 (configurable)
- Outcome:
  - Pass → proceed to generation pipeline
  - Fail → decline with per-signal reasons (UI + JSON), no AI spend

Status: Gate is enforced in the pipeline by default. It can be explicitly disabled via
`REQUIRE_PROFILE_ELIGIBILITY=0` for paid/Stripe modes only (see roadmap PR 14).

## 5) Orchestrated Generation Pipeline

All steps return `ServiceResult` and are non-destructive; failures are logged with structured
context.

1. Sync from GitHub
   - Service: `Profiles::SyncFromGithub`
   - Populates `Profile` and associations: repos, orgs, languages, social accounts, activity,
     README.
   - Downloads avatar to `public/avatars/<login>.*`.
   - Preserves `submitted` repositories (does not delete them).

2. Ingest manual repositories (optional)
   - Service: `Profiles::IngestSubmittedRepositoriesService`
   - For each `owner/repo`, fetch metadata + topics and persist as
     `ProfileRepository(repository_type: 'submitted')`.
   - Idempotent; up to 4 repos; logs and skips invalids.

3. Scrape manual URL (optional)
   - Service: `Profiles::RecordSubmittedScrapeService` → calls `Scraping::ScrapeUrlService`.
   - Fetch limits: HTML only, ≤ 2MB body, 10s timeouts, ≤ 3 redirects; blocks localhost/private
     ranges; normalize links (≤ 50); cap text (≤ 20k chars).
   - Persists a `ProfileScrape` record with title, description, canonical_url, text, links,
     content_type, http_status, bytes, fetched_at.
   - Non-fatal on failure.

4. Synthesize card data
   - Service: `Profiles::SynthesizeCardService`
   - Produces `ProfileCard` (title, tags, traits, stats) from signals.

5. Generate avatar images
   - Service: `Gemini::AvatarImageSuiteService` (provider: AI Studio or Vertex)
   - Produces 1x1, 16x9, 3x1, 9x16 variants; records artifacts via `ProfileAssets::RecordService` if
     configured.

6. Capture screenshots
   - Service: `Screenshots::CaptureCardService` (Node Puppeteer driver; ADR-0002)
   - Routes captured: `/cards/:login/(og|card|simple)`
   - Saves PNGs; optional optimization via `Images::OptimizeService`.

7. Upload (optional)
   - Service: `Storage::ActiveStorageUploadService` (when enabled)
   - Stores public URLs (DO Spaces/S3) and records `ProfileAsset` entries.

8. Return pipeline result
   - Pipeline: `Profiles::GeneratePipelineService` orchestrates the above; returns artifact
     paths/ids.

## 6) Ownership & Limits

- My Profiles lists only profiles you own (single-owner model).
- First-time self-claim: first submitter becomes owner if no owner exists.
- Non-rightful submit allowed when no owner: first submitter becomes owner.
- Rightful owner later claims: takeover replaces prior owner; other links removed.
- Duplicate submission by non-owner when already owned: rejected.
- Admin transfer: sets new owner; removes other links.
- Per-user cap: default 5 profiles per user.

## 7) Where Data Lives

- Profile core: `profiles`
- Repositories: `profile_repositories` (+ `repository_topics`)
- Languages: `profile_languages`
- Organizations: `profile_organizations`
- Social accounts: `profile_social_accounts`
- Activity: `profile_activities`
- README: `profile_readmes`
- Card: `profile_cards`
- Assets: `profile_assets`
- Submitted scrape: `profile_scrapes`

See: `docs/github-profile-data.md` for full schema details.

## 8) Error Handling & Observability

- All services return `ServiceResult` and structured logs: status, error_class, error message,
  metadata.
- Pipelines prefer retries and fallbacks; AI calls must not block the entire flow.
- Health: Mission Control (jobs UI) planned; logs carry provider + model + tokens for Gemini
  services.

## 9) Implementation Status Summary

- Auth: implemented
- Submission UX: partially implemented (marketing only); form + controller pending
- Eligibility gate: service implemented; enforcement pending in pipeline/job
- Ownership (“My Profiles”): not implemented
- Pipeline: implemented with optional manual-inputs pre-steps (flag-gate recommended)
- Persistence of scrape/manual repos: implemented services + migrations

## 10) Next Actions to Wire UX

1. Add submit controller + form:
   - Capture `login`, optional `submitted_scrape_url`, optional up to 4 `owner/repo` strings
   - Enforce eligibility gate before enqueueing generation
2. Add “My Profiles” page and link User ↔ Profile
3. Feature flag the manual-input pre-steps in pipeline
4. Add UI surfaces to display scraped excerpt and manual repos on profile page

---

References: README.md, docs/application-workflow.md, docs/auth-and-ownership.md,
docs/submit-manual-inputs-workflow.md, docs/roadmap.md.
