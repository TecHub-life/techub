# Submit Manual Inputs — End-to-End Workflow (Spec)

Status: Spec only (implementation partial; do not assume wired)

## Goal

Allow a user submitting a profile to specify:

- Optional personal URL to scrape for extra context (one URL)
- Up to 4 GitHub repositories by full name (`owner/repo`)

We use these inputs to augment the profile and ensure important work is not missed by automation.

## Entry Points

- UI: Submit page (post-auth)
  - Fields:
    - `login` (required)
    - `submitted_scrape_url` (optional, one URL)
    - `submitted_repositories[]` (optional, up to 4 strings `owner/repo`)

## Validation Rules

- `submitted_scrape_url`
  - Must be a valid HTTP/HTTPS URL
  - SSRF protections: block localhost and private networks
  - Content-Type must be HTML (text/html or application/xhtml)
  - Timeouts: 10s open/read; max 3 redirects; max 2MB body

- `submitted_repositories`
  - 1..4 items; each must match `^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$`

## Data Model

- `profiles.submitted_scrape_url` (nullable string)
- `profile_repositories.repository_type = 'submitted'` (preserved across sync)
- `profile_scrapes` (new table) — store last scrape for the submitted URL
  - `profile_id`, `url`, `title`, `description`, `canonical_url`, `text`, `links (json)`,
    `content_type`, `http_status`, `bytes`, `fetched_at`

## Services (SOLID)

- `Profiles::IngestSubmittedRepositoriesService`
  - Input: `profile`, array of repo full names (max 4)
  - Behavior: fetch via GitHub API; upsert as `ProfileRepository` with
    `repository_type: 'submitted'`; record topics; idempotent
  - Output: `ServiceResult.success([profile_repository, ...])` or failure

- `Scraping::ScrapeUrlService`
  - Input: `url`, limits (max_bytes, timeout, redirects, max_text_chars, max_links)
  - Behavior: HTTP GET with caps and SSRF protections; parse HTML with Nokogiri; extract title,
    description, canonical, visible text (capped), absolute links (capped)
  - Output: `ServiceResult.success({ title, description, canonical_url, text, links })` or failure

- `Profiles::RecordSubmittedScrapeService`
  - Input: `profile`, `url`
  - Behavior: call scraper; upsert `ProfileScrape` with content + metadata
  - Output: `ServiceResult.success(profile_scrape)` or failure

## Orchestration (Pipeline)

Ordering when generating a profile (happy path):

1. Sync from GitHub → ensure `Profile` exists and is current
2. If present, ingest submitted repos (idempotent; preserve type `submitted`)
3. If present, scrape `submitted_scrape_url` and persist to `ProfileScrapes`
4. Synthesize card attributes
5. Generate avatar images
6. Capture screenshots
7. Optimize images (optional)

Notes:

- Steps 2 and 3 are optional and non-fatal; failures are logged and do not block the pipeline.
- Sync must not delete `submitted` repositories.

## Failure Handling

- All services return `ServiceResult`.
- On scraper/network failures: log with context, continue without scraped content.
- On invalid repo names: skip gracefully; include warning logs.

## Observability & Limits

- Scraper logs: status, URL, http_status, content_type, bytes, timings
- Enforce caps (2MB body, 10s timeouts, 3 redirects, 20k chars of text, 50 links)
- Optional host allowlist (config) for stricter environments

## Test Plan

- Unit tests (hermetic; WebMock):
  - Scraper success (link normalization, canonical, text cap)
  - Scraper failures: invalid URL, SSRF, non-HTML, redirects
  - Repo ingest: creates/updates `submitted` repos and topics
  - Record service: persists scrape record with metadata

- Integration (future, optional):
  - Pipeline step executes ingest + record when inputs present (stub GitHub/HTTP)

## Implementation Status

- Schema: `profiles.submitted_scrape_url`, `profile_scrapes` — defined
- Services: scraper, record, ingest — implemented
- Sync: preserves `submitted` repos — implemented
- UI: submit form + controller wire-up — NOT implemented
- Pipeline: pre-steps present; still needs feature flag and clearer logging/failover docs

## Rollout Plan

1. Ship docs + ADRs (done) and feature flag (`SUBMISSION_MANUAL_INPUTS_ENABLED`)
2. Add submit form/controller; validate inputs; store URL and repo list
3. Gate pipeline steps 2–3 behind the flag
4. Add UI surface for scraped excerpt and links (optional)
5. Monitor metrics and logs; tune limits as needed
