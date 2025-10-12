# ADR-0003: Submit page manual inputs for scrape URL and repositories

## Status

Proposed

## Context

Automated GitHub ingestion (repos, languages, activity, README, orgs) can miss important
repositories a user wants highlighted, and some users want us to consider a personal URL for
scraping additional context. We need a durable way to capture user intent during submission so it
flows through data sync, orchestration, and presentation without being wiped by refreshes.

## Decision

- Extend the submit flow to accept:
  - An optional personal URL to scrape (one URL).
  - Up to 4 GitHub repositories by full name (`owner/repo`).
- Persist the inputs:
  - Add `profiles.submitted_scrape_url` (nullable, text/string).
  - Store repositories as `ProfileRepository` rows with `repository_type: "submitted"`.
- Adjust sync/orchestration:
  - `Profiles::SyncFromGithub` should only replace `top`/`pinned`/`active`, preserving `submitted`.
  - The generation pipeline ingests `submitted` repos (fetch metadata/topics) and queues a scrape
    job for `submitted_scrape_url`.

## Consequences

Positive

- Users can ensure key work is represented even if automation misses it.
- Manual inputs become first-class and survive repeated syncs.
- Minimal schema change; reuses existing `profile_repositories` table.

Negative / Considerations

- Requires validation and guardrails (max 4 repos; valid full_name; URL hostname allow/deny list).
- Sync logic must avoid deleting `submitted` rows.
- Potential scraping cost; needs rate limiting and timeouts.

## References

- Roadmap PR 18 — Submit: manual inputs + scraping
- Application workflow additions (submission UX, orchestration pre-steps)
- GitHub profile data doc updates (repository_type: `submitted`)

## Review Date

2025-12-01

## Decision Makers

Loftwah, Jared

## Related ADRs

- ADR-0001 (eligibility gate)
- ADR-0002 (screenshot driver)

## Implementation Status

- Not implemented; documented and planned in `docs/roadmap.md`.
