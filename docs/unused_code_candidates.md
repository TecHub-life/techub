### Unused/Obsolete Code Candidates

- Motifs generation stack (mark for removal):
  - `app/services/motifs/generate_library_service.rb`
  - `app/services/motifs/generate_lore_service.rb`
  - `app/jobs/motifs/ensure_job.rb`
- Verify call sites before deletion; current references are limited to the motifs job and internal
  service calls. No routes or schedules auto-run these in production.
