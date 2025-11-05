## Pipeline Observability

Techub's profile pipeline now records rich snapshots that you can inspect locally or surface in the Ops panel. This document explains how to capture a run, where the artifacts live, and how to review them.

### Running The Pipeline Snapshot Export

Use the new rake task to execute the full pipeline and persist a snapshot:

```bash
rake pipeline:run[loftwah]
```

By default this:

- executes `Profiles::GeneratePipelineService` end-to-end
- skips live Gemini calls by using the existing card data or heuristic fallback (`ai_mode: mock`)
- saves artifacts under `tmp/pipeline_runs/<timestamp>-<login>/`
- copies any locally generated screenshots into a `captures/` subdirectory

Each run writes:

- `metadata.json` – top-level service metadata (run id, duration, trace)
- `pipeline_snapshot.json` – serialisable view of the pipeline context (GitHub payload, profile, card, captures, optimisations)
- `stage_metadata.json` – per-stage status, timings, and enriched metadata (prompt details, screenshot manifests, etc.)
- `ai_prompt.json` / `ai_metadata.json` – Gemini system prompt + payload context, response preview and attempt log
- `trace.json` – trace entries emitted during the run
- `captures/` – copied screenshots for quick viewing (if generated)

### Environment Flags

| Flag | Default | Description |
| --- | --- | --- |
| `PIPELINE_SAVE` | `1` | Set to `0` to skip writing artifacts (useful for a dry run). |
| `PIPELINE_FORCE` | `0` | Set to `1` to force live Gemini calls (`ai_mode: real`). |
| `PIPELINE_AI_MODE` | `mock` | Explicitly choose `mock` or `real`. `PIPELINE_FORCE=1` overrides this. |
| `PIPELINE_SCREENSHOTS_MODE` | *(unset)* | Set to `skip` to bypass the screenshot capture stage when exporting. |
| `PIPELINE_HOST` | fallback host | Override the host passed into the pipeline (handy for staging/local). |

Example invocations:

```bash
# Real Gemini run, keep artifacts
PIPELINE_FORCE=1 rake pipeline:run[octocat]

# Quick verification without saving to disk
PIPELINE_SAVE=0 PIPELINE_AI_MODE=mock rake pipeline:run[loftwah]

# Skip screenshots when you only care about AI output
PIPELINE_SCREENSHOTS_MODE=skip rake pipeline:run[loftwah]
```

### Ops Panel Snapshot Viewer

The Ops panel (`/ops`) now includes a “Pipeline Snapshot” block on the Pipeline tab. Features:

- Login selector populated from `tmp/pipeline_runs/`
- Run summary (run id, duration, snapshot path)
- Stage timing table with per-stage notes (degraded, heuristics, mock indicators)
- GitHub payload summary (profile stats + summary text)
- AI card overview (title, tagline, vibe, model)
- Gemini prompt/response previews (system prompt + JSON context inside an expandable section)
- Screenshot manifest showing local paths and uploaded URLs
- Download links for the raw snapshot files via `/ops/pipeline_snapshot?login=<login>&file=<name>`

Use the “Load” button to refresh the view after you capture a new run; the `tab=pipeline` parameter keeps the Pipeline tab active.

### Stage Metadata Enrichment

While the pipeline runs, each stage now records richer metadata that travels with the snapshot:

- **GitHub fetch** stores a summary of follower counts, repo counts, and orgs.
- **AI profile generation** includes provider, attempt log, prompt payload, and response preview. Mock runs record that status explicitly.
- **Screenshot capture** records variant manifests with local paths and DO Spaces URLs.
- **Image optimisation** captures before/after byte counts per variant.

These details appear in `stage_metadata.json`, the Ops panel stage table, and the `metadata.json` payload.

### Tips

- The `trace.json` file mirrors the internal trace entries if you want to diff granular events between runs.
- If you want to compare two snapshots manually, diff the `pipeline_snapshot.json` files – they’re ordered consistently for easier `diff` output.
- Add your own fixtures to `tmp/pipeline_runs` and the Ops panel will pick them up automatically; only the folder naming convention (`<timestamp>-<login>`) matters.
