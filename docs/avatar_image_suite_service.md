### Gemini::AvatarImageSuiteService — Purpose and Usage

- Responsibility: Orchestrate prompts → image generation across variants (1x1, 16x9, 3x1, 9x16),
  write artifacts, and optionally upload + record assets. It composes:
  - `Gemini::AvatarPromptService` for prompts (uses `ImageDescriptionService` when enabled)
  - `Gemini::ImageGenerationService` for image bytes and file writing
  - `Images::OptimizeService` for conversion to JPEG by default
  - `ProfileAssets::RecordService` for persistence

- Inputs: `login`, optional `avatar_path`, `prompt_theme`, `style_profile`, `provider`,
  `output_dir`.
- Outputs: a hash of generated variants with `output_path`, `mime_type`, and `aspect_ratio`.
- Flags: honors `FEATURE_FLAGS[ai_images]` and upload toggles. Supports
  `require_profile_eligibility` gating.

- Notes: This is an orchestrator; leaf services do single things. Avoid adding business branching
  here that isn’t about image suite generation.
