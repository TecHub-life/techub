# Dev Verification – 2025-11-11

## Gemini structured JSON failure capture

- Command:
  `bin/rails runner 'Profiles::GeneratePipelineService.call(login: "mamirul47", overrides: { trigger_source: "dev_console" })'`
- Outcome: pipeline completed with partials due to `generate_ai_profile` degradation at
  `2025-11-11T10:19:53Z`. See `log/development.log:44361` for the `Gemini::StructuredOutputService`
  failure (invalid structured JSON) and the truncated `raw_preview` payload, plus
  `log/development.log:44362` for `Profiles::SynthesizeAiProfileService`.
- Evidence: the pipeline trace + metadata for this run lives in `tmp/pipeline_run_1762856818.json`.
  The degraded step recorded at the pipeline layer is also logged in `log/development.log:45539`
  (`pipeline_completed_degraded` with `degraded_steps: [{stage: :generate_ai_profile}]`).
- Next step: to capture the _full_ Gemini payload on demand, temporarily add instrumentation inside
  `Gemini::StructuredOutputService` (e.g., `Rails.logger.info(response.body)` or write to
  `tmp/gemini_payload_<timestamp>.json`) before rerunning the pipeline.

## PDF ingestion regression verification

- Command:
  ```bash
  bin/rails runner 'require "json"; profile = Profile.for_login("mamirul47").first; pdf_url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"; profile.update!(submitted_scrape_url: pdf_url); context = Profiles::Pipeline::Context.new(login: profile.login, host: "http://127.0.0.1:3000"); context.profile = profile; stage = Profiles::Pipeline::Stages::RecordSubmittedScrape.call(context: context); puts({ success: stage.success?, degraded: stage.degraded?, trace: context.trace_entries.map(&:to_h) }.to_json)'
  ```
- Output:
  `{"success":true,"degraded":false,"trace":[...,{"event":"skipped","reason":"unsupported_content_type"}]}`
  proving PDFs now skip cleanly without degrading the pipeline.
- Evidence: console output captured above plus the trace entry stored on the context (see
  `Profiles::GeneratePipelineService` trace snapshot in `tmp/pipeline_run_1762856818.json`).

## Axiom logging forwarder smoke test

- Command: `AXIOM_ENABLED=1 bundle exec rake axiom:runtime_doctor`
- Output: forwarder forced a synchronous delivery (`status=200 at=2025-11-11T10:19:19.435Z`) and
  drained the async queue. This proves the dev host can reach the `otel-logs` dataset once AXIOM is
  enabled explicitly for the session.
- Supplemental: `StructuredLogger.info(message: "axiom_probe", force_axiom: true)` emitted at
  `log/development.log:43976`. Without `AXIOM_ENABLED=1`, the runtime doctor exits with
  `forwarding_allowed: false (reason=disabled)`—set that env var when you need end-to-end
  verification.

## Pipeline partials vs heuristic fallback

- After updating `Profiles::Pipeline::Stages::GenerateAiProfile` (heuristic branch now calls
  `success_with_context`), fallback runs no longer mark the pipeline degraded. Capture logs for
  confirmation: `tmp/pipeline_runs/s0ands0_20251111111744_full.json` and
  `tmp/pipeline_runs/loftwah_20251111114306_full.json` show heuristic completions without degraded
  steps.

## Extra observations

- A later pipeline run (`tmp/pipeline_run_1762856818.json`) failed at `capture_card_screenshots`
  because `Screenshots::CaptureCardService` reported `asset_not_recorded` for variant `og`. This is
  orthogonal to the Gemini/JSON issue but worth tracking if screenshot workers remain offline on the
  dev box.

## Recent pipeline spot-checks (skip screenshots to isolate data stages)

- `mamirul47`: `tmp/pipeline_runs/mamirul47_20251111103259.json` shows a clean run when
  `skip_stages` omits screenshots; earlier run (`tmp/pipeline_run_1762856818.json`) reproduced the
  screenshot failure + fallback.
- `glowstudent777`: `tmp/pipeline_runs/glowstudent777_20251111103326.json` failed inside
  `Profiles::SynthesizeCardService` with `Tags must contain exactly 6 items` because language/topic
  tags collapse after slugging. This is our repro of the “validation failed” alert.
- `s0ands0`: `tmp/pipeline_runs/s0ands0_20251111103350.json` succeeded but `generate_ai_profile`
  degraded due to heuristic fallback after Gemini JSON parsing failed.
- `marcindudekdev`: `tmp/pipeline_runs/marcindudekdev_20251111103407.json` succeeded end-to-end
  (Gemini returned structured JSON on the first attempt despite the profile having zero
  repos/languages).
- `loftwah`: `tmp/pipeline_runs/loftwah_20251111103436.json` also hit the heuristic fallback route,
  leaving the pipeline marked `partial`.

Use these JSON captures when adding regression tests or when replaying specific stages via
`Profiles::Pipeline::Context`.

## Full pipeline reruns (screenshots enabled)

- `tmp/pipeline_runs/mamirul47_20251111110249_full.json`: full run with screenshots completes
  successfully after tag/fallback fixes.
- `tmp/pipeline_runs/glowstudent777_20251111110839_full.json`: previously failing profile now
  finishes without validation errors; stage metadata shows six normalized tags persisted.
- `tmp/pipeline_runs/s0ands0_20251111111744_full.json` (and follow-up `...13252_full.json`):
  pipeline succeeds; heuristic metadata present but overall outcome is `success`.
- `tmp/pipeline_runs/marcindudekdev_20251111113827_full.json`: still green despite sparse GitHub
  data.
- `tmp/pipeline_runs/loftwah_20251111114306_full.json`: all stages succeed until
  `capture_card_screenshots`, which fails with `asset_not_recorded` because the local Puppeteer
  worker isn’t running. Treat this as an environment limitation rather than a regression.

## Gemini failure dumps

- `app/integrations/gemini/structured_output_service.rb` now writes any invalid-response payload to
  `tmp/gemini_failures/<timestamp>_<provider>_<reason>.json` and emits a
  `gemini_structured_output_failure` entry via `StructuredLogger`. The next time prod sees
  `undefined method 'human'` or `Invalid structured JSON`, grab the dump file for adapter work
  instead of relying on truncated log previews.
