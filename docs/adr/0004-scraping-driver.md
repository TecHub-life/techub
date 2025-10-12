# ADR-0004: Scraping driver — Puppeteer vs. Nokogiri + Net::HTTP

## Status

Proposed

## Context

We need to scrape a user-provided personal URL during profile submission (optional) to extract
structured content (title, description, visible text, links). We already use Puppeteer (Node) for
rendering screenshots. For scraping, we must balance robustness, resource usage, and safety.

## Options Considered

1. Puppeteer (headless browser)

- Pros: Handles JS-heavy sites, consistent DOM after hydration, familiar from screenshots pipeline.
- Cons: Heavy to boot per request; increased resource usage and latency; more moving parts (Node
  bridge); overkill for simple content extraction; security sandboxing is trickier.

2. Ruby HTTP + Nokogiri (no JS execution)

- Pros: Lightweight, fast, fewer dependencies; easy to run inside Rails; good enough for most static
  content; easier to apply SSRF protections and timeouts.
- Cons: JS-dependent sites may render empty or partial content; requires heuristics for main text.

## Decision

Adopt Ruby-based scraping with `Net::HTTP` and `Nokogiri` for submission URL parsing. Implement a
service `Scraping::ScrapeUrlService` with:

- Strict URL validation, SSRF protections (block localhost/private ranges), host allowlist support.
- Timeouts, redirect limits, and size caps (2MB default) on downloads.
- Content-type checks (HTML only).
- HTML parsing to extract title, meta description/OG description, canonical URL, visible text, and
  up to 50 normalized links.

## Consequences

Positive

- Low overhead and simple deployment; stays within Rails Ruby services.
- Clear error handling and caps to control cost and risk.
- Works well for static and many modern sites with server-rendered content.

Negative

- JS-only content may be incomplete. If this becomes common, we can add an optional Puppeteer-based
  fallback behind a feature flag for those domains.

## Implementation Notes

- Implemented: `app/services/scraping/scrape_url_service.rb`.
- Add `nokogiri` gem to Gemfile.
- Future: Add a small domain allowlist and per-request feature flag in the pipeline.

## Review Date

2026-01-15

## Decision Makers

Loftwah, Jared

## Related ADRs

- ADR-0002 (screenshot driver — Puppeteer)
- ADR-0003 (submit manual inputs)
