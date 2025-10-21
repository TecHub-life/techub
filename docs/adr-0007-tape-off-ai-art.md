# ADR-0007: Tape Off AI Image Generation and Descriptions

Context:

- Programmatic AI image generation (avatars and supporting art) incurred unexpected costs.
- We still want AI-generated text for profiles, but not AI images for now.
- We may re-enable image generation later for paid accounts; we must preserve interfaces and avoid
  breaking the pipeline.

Decision:

- Add feature flags to disable AI image generation and avatar image descriptions while keeping the
  codepaths and public interfaces intact.
  - `GEMINI_AI_IMAGES_ENABLED` (default: off) — gates `Gemini::ImageGenerationService`.
  - `GEMINI_IMAGE_DESCRIPTIONS_ENABLED` (default: off) — gates `Gemini::AvatarDescriptionService`.
- When disabled, the services immediately return a failure result with a descriptive reason in
  metadata. Upstream callers already degrade gracefully:
  - `Profiles::GeneratePipelineService` marks the run partial and continues with screenshots.
  - `Gemini::AvatarPromptService` synthesizes prompts from profile context when description is
    unavailable.
- Replace AI artwork in the product with pre-existing assets:
  - Pre-made avatars under `app/assets/images/avatars-1x1/`.
  - Supporting art under `app/assets/images/supporting-art-1x1/`.
- Keep all image-generation code in place (SOLID boundaries retained) so paid tiers can re-enable
  later by flipping flags.

Operational Controls:

- Access gating added to enforce a small allowlist until launch:
  - DB-backed settings via `AppSetting`:
    - `open_access` (boolean)
    - `allowed_logins` (JSON array)
  - Manage from `/ops` (Access Control panel). Defaults to off with `allowed_logins`:
    `["loftwah","jrh89"]`.
  - Login flow respects these settings and shows a friendly message if not allowed.

Status: Accepted.

Consequences:

- Drastically reduced AI costs. No AI image calls in development by default; production remains off
  unless explicitly enabled with env vars.
- Future re-enable requires only setting `GEMINI_IMAGE_DESCRIPTIONS_ENABLED=1` and
  `GEMINI_AI_IMAGES_ENABLED=1`.
- Structured/text profile synthesis remains unchanged.
