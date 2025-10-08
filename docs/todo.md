### PR Checklist

- [ ] PR 01: Add Gemini client, config/env validation, and healthchecks — In Progress
- [ ] PR 02: Implement AvatarDescriptionService (vision) using service result pattern — Pending
- [ ] PR 03: Implement ProfileSynthesisService (structured output) with schema + ordering — Pending
- [ ] PR 04: Add validators for lengths/traits + re-ask loop on violations — Pending
- [ ] PR 05: Minimal DB migrations for ai_profiles + assets (text fields + metadata) — Pending
- [ ] PR 06: Avatar fetch-and-store to DO Spaces + hash/dimensions — Pending
- [ ] PR 07: PipelineOrchestrator service composing steps with success/failure results — Pending
- [ ] PR 08: OG image route (1200x630) + screenshot job and storage — Pending

Notes

- Use Vertex AI (service account) as the default Gemini provider; allow AI Studio API key only as a
  dev fallback.
- Model is locked to `gemini-2.5-flash` across environments.
- Every service returns `ServiceResult` with success/failure and metadata for traceability.
