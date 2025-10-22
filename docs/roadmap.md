# Roadmap (Simplified)

The codebase is the source of truth. This roadmap only lists what’s useful going forward. If it
disagrees with code, the code wins.

Completed (recent)

- Manual inputs always on (fail‑safe). Submitted repos/URL are ingested/scraped when present;
  failures log and continue.
- Pipeline gates simplified and visible in Ops:
  - AI Images and AI Image Descriptions (costed, default OFF)
  - AI Text and AI Structured Output (default ON)
- Regeneration streamlined: default path is sync + text + screenshots; image regeneration removed
  from Ops bulk flows.
- Recurring freshness: stale profiles auto‑run pipeline with `images: false`.
- Daily stats snapshots: `ProfileStat` (followers, following, stars, forks, repo_count) recorded
  daily and logged for Axiom.
- Docs pipeline: sanitized markdown rendering; relative image paths rewritten.

Now

- Observability: Axiom + OTEL
  - Logs: Verify ingest via Ops “Axiom Smoke Test”. Ensure `AXIOM_TOKEN`/`AXIOM_DATASET` are set;
    use `AXIOM_ENABLED=1` in non‑prod.
  - Traces: Add OpenTelemetry gems + initializer and export to Axiom OTLP.

- Docs reliability
  - Keep `/docs` error‑free; sanitize/fallback cleanly for problematic files.

Next

- Ops: Stale indicators
  - Show count + sample list of stale cards in `/ops` (no Settings UI changes).

- Guardrails
  - Contract tests for image generation/upload; pipeline step write assertions; keep costed AI
    gated.

Later (nice‑to‑haves)

- Avatar style variants (preset recipes) — surface choices in Settings (no generator changes).
- Motifs: curated static assets with optional theme switcher in Ops.

Notes

- Removed obsolete docs/notes and root `todo.md` to avoid confusion.
- If a section becomes stale, we prune rather than carry forward cruft.
