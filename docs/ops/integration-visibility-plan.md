## Ops Integration Visibility Roadmap

Goal: every external dependency (Gemini, GitHub, Axiom, DigitalOcean Spaces) must have observable
status inside the Ops panel, support on-demand verification, and emit artifacts/details that make
failures actionable. This plan describes the work required to get from the current CLI-only doctor
to the desired “warm & fuzzy” dashboard.

---

### 1. Current State (Nov 2025)

- `bundle exec rails ops:doctor` runs all integration probes and streams progress to STDOUT.
- Results exist only in the final JSON payload; nothing is persisted or surfaced in `/ops`.
- Gemini image/text probes write temporary artifacts under `tmp/integration_doctor/` but aren’t
  retained or linked anywhere.
- Some subsystems already have bespoke controls in `/ops` (pipeline doctor, Axiom smoke button,
  backup probes), but there is no unified Integrations panel or historical record.
- Simple/cheap health checks (Gemini text, Axiom ingestion, Spaces upload) do not auto-run at boot.

---

### 2. Target Experience

1. **Ops UI visibility**
   - Dedicated “Integrations” section showing each subsystem, provider, and capability.
   - Clear status light (OK/Warn/Fail) with timestamps of last success and last failure.
   - Drill-down view with metadata (duration, HTTP status, provider, error message) and any
     generated artifacts (e.g., Gemini images/JSON).
2. **Manual control**
   - Buttons/toggles in the Ops UI to rerun the entire doctor or specific scopes (Gemini-only,
     GitHub-only, etc.).
   - Ability to restrict to a single provider (`ai_studio`, `vertex`) from the UI.
3. **Automatic probes**
   - Cheap checks (Gemini text, Spaces upload, Axiom ingest, GitHub app token) run automatically on
     boot or via scheduled job, seeding the panel with a green baseline.
4. **Persistent history**
   - Probe results stored in the database (at least last result per scope/provider + audit history).
   - Attachments/paths for generated artifacts persisted so Ops can view them later.
5. **Alerting hooks**
   - Optional email/slack/StructuredLogger notifications when a probe fails or when automatic probes
     haven’t run within a SLA window.

---

### 3. Work Breakdown

#### 3.1 Persistence Layer

- Create `IntegrationProbe` model (or similar) with fields:
  - `scope` (`gemini`, `github`, `axiom`, `spaces`, etc.)
  - `provider` (nullable; e.g., `ai_studio`, `vertex`)
  - `check_name` (`gemini.ai_studio.text_to_image`)
  - `status` (`ok`, `warn`, `fail`)
  - `metadata` (JSON column for raw response)
  - `output_paths` / `artifact_urls` (JSON)
  - `started_at`, `finished_at`, `duration_ms`
  - `trigger` (`manual`, `auto_boot`, `scheduler`, `ops_ui`)
  - indexes on `scope`, `provider`, `status`, `finished_at`.
- Extend `Ops::IntegrationDoctorService` to accept an optional `record:` flag (default true) and
  persist each check via the new model.
- Move artifact storage from `tmp/` to a dedicated directory (e.g., `storage/integration_probes/`)
  and store relative paths in the DB; optionally upload to Spaces to avoid local churn.

#### 3.2 Ops Panel UI

- Add “Integrations” card on `/ops` with:
  - Summary table per scope/provider showing:
    - Status icon, last success timestamp, last failure timestamp, duration.
    - “Run now” buttons for the entire scope or specific provider.
  - Detail drawer/modal that lists the latest N probe entries with metadata and links to artifacts.
  - Filter chips for scopes/providers.
- Hook “Run now” buttons to a new controller action that enqueues `Ops::IntegrationDoctorJob` with
  the chosen scope/provider. Display flash message referencing the job ID.
- Show “Pending/Running” state when a probe is in flight (Solid Queue job status, last started at).

#### 3.3 Background Jobs & Scheduling

- Wrap the doctor service in `Ops::IntegrationDoctorJob` (Active Job) that:
  - Streams logs to Rails logger.
  - Persists results via the model.
  - Optionally notifies Ops on failure (via email/StructuredLogger).
- Add a boot hook (initializer or after Solid Queue start) that enqueues a limited-scope run
  covering the cheap checks (Gemini text, Axiom ingest, Spaces upload, GitHub app token).
- Add a scheduled task (Solid Scheduler or cron) to re-run probes every X hours and update the panel
  automatically.

#### 3.4 Artifact Handling

- After each Gemini image probe, copy generated files to `storage/integration_probes/<probe_id>/`.
- Provide view/download links in the Ops panel detail view; ensure files are pruned based on age or
  after a retention window.
- Optionally upload artifacts to Spaces/S3 when remote storage is enabled, storing the public URL.

#### 3.5 Boot-Time Signals

- During application boot (or first request), run:
  - Gemini text-only probe (cheap).
  - Axiom ingest probe (single log event).
  - Spaces upload probe (small text file).
  - GitHub app token fetch.
- Record those as `trigger: "auto_boot"` so the Ops panel immediately shows a green baseline without
  manual intervention.

#### 3.6 Notifications & Alerts (optional stretch)

- Add AppSetting toggles for “notify on probe failure.”
- When a probe fails, send:
  - Email to ops list (if configured).
  - StructuredLogger event (force_axiom) with metadata for incident tracking.
  - Optional Slack webhook (if available).
- Surface recent failures in `/ops` with inline CTA to rerun.

---

### 4. Implementation Sequencing

1. **Persistence + Job wrapper**
   - Ship the `IntegrationProbe` model + migration.
   - Update `Ops::IntegrationDoctorService` to write probe rows and store artifacts.
   - Add `Ops::IntegrationDoctorJob`.
2. **Ops Panel UI (read-only)**
   - Display probe summary/history using stored data (no buttons yet).
3. **Ops Panel controls**
   - Add “Run now” actions that enqueue the job with selected scopes/providers.
4. **Artifact surfacing**
   - Link generated Gemini images/JSON in the detail view.
5. **Boot + scheduled probes**
   - Auto-run cheap checks on boot; add scheduler for periodic runs.
6. **Notifications (optional)**
   - Wire alerts for failures + stale probes.

---

### 5. Acceptance Criteria

- Ops panel shows up-to-date status for each integration with timestamps and metadata.
- Button-driven probes from `/ops` update the panel and store artifacts.
- Automatic probes populate the panel shortly after boot.
- Historical records exist (at least recent entries) for audit/debug.
- All functionality documented (update ops runbook + gemini docs).

Once these steps are complete, you’ll have the “green light” dashboard with full visibility and
control over every external mechanism, eliminating the need to trust terminal output or tribal
knowledge. Let me know if you want milestones broken into tickets or if we should prioritize a
subset (e.g., Gemini first, then storage/Axiom).
