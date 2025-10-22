# Critical Services

This document lists the core services that must remain stable and obvious. Each entry shows what it
does and where it lives.

- AI image descriptions
  - Purpose: Generate short descriptions of images for avatars and assets
  - Code: `app/services/gemini/image_description_service.rb`
- AI image generation
  - Purpose: Generate images given prompts/aspect hints
  - Code: `app/services/gemini/image_generation_service.rb`
- AI structured output
  - Purpose: Produce JSON traits for profiles with schema constraints
  - Code: `app/services/profiles/synthesize_ai_profile_service.rb`
  - Helpers: `app/services/gemini/response_helpers.rb`,
    `app/services/gemini/text_generation_service.rb`,
    `app/services/gemini/structured_output_service.rb`
- AI text generation
  - Purpose: Free-form text (stories/bios) from profile context
  - Code: `app/services/gemini/text_generation_service.rb`,
    `app/services/profiles/story_from_profile.rb`
- Storage management
  - Purpose: Upload generated assets to Spaces (S3-compatible), record artifacts
  - Code: `app/services/storage/active_storage_upload_service.rb`,
    `app/services/profile_assets/record_service.rb`
- Image optimisation
  - Purpose: Optimize generated images (VIPS when enabled; ImageMagick fallback)
  - Code: `app/services/images/optimize_service.rb`, job `app/jobs/images/optimize_job.rb`
- Screenshot capture
  - Purpose: Render HTML card views into images for OG/card/social variants
  - Code: `app/services/screenshots/capture_card_service.rb`, job
    `app/jobs/screenshots/capture_card_job.rb`, script `script/screenshot.js`
- GitHub login & auth flow
  - Purpose: Session/auth for users via GitHub OAuth
  - Code: `app/controllers/sessions_controller.rb`, routes `config/routes.rb` (`/auth/github`,
    `/auth/github/callback`)

Supporting docs

- Library assets
  - Avatars: `app/assets/images/avatars-1x1/`
  - Supporting art: `app/assets/images/supporting-art-1x1/`
- Rendering rules
  - `docs/asset-guidelines.md`, `docs/og-images.md`
- Observability
  - Structured logging: `config/initializers/structured_logging.rb`
  - Ops jobs UI: `/ops/jobs` (Mission Control)

Notes

- AI generation is taped off by default. Library assets are used unless admin explicitly enables AI
  paths.
- Do not remove or change these services without updating this document.
