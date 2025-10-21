### Services Refactor Plan

Goal: enforce SOLID boundaries and DRY abstractions for AI and pipelines. Align names to
responsibilities; separate orchestration from execution.

- Rename: `Gemini::AvatarDescriptionService` → `Gemini::ImageDescriptionService` (done; no shim).
- Introduce:
  - `Gemini::ImageDescriptionService` (done)
  - `Gemini::TextGenerationService` (added)
  - `Gemini::StructuredOutputService` (added)
- Keep: `Gemini::ImageGenerationService` (image bytes + write optional file)
- Coordinator services should compose leaf services only, returning `ServiceResult`.

Removal candidates (obsolete):

- `Motifs::GenerateLibraryService` and `Motifs::GenerateLoreService` — replace with curated static
  assets or separate utility rake tasks if still needed. Also remove `app/jobs/motifs/ensure_job.rb`
  and associated routes/views that depend on runtime generation.

Follow-ups:

- Delete `AvatarDescriptionService` relics; all references migrated.
- Centralize Gemini provider selection and response handling in helpers used by all AI services.
- Split screenshot orchestration from views; validate each social target has a dedicated template.
- Document service boundaries in `docs/architecture/services.md` and add contract tests per service.
