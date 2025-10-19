# Style variants workflow

We support stylistic variations for AI-generated assets while avoiding IP issues.

## Principles

- No direct use of copyrighted/trademarked characters (e.g., Homer Simpson, Marvel heroes, GitHub
  Octocat).
- Use generic descriptors: "animated sitcom style", "comic book hero style", "mascot cat tech icon
  style".
- Keep constraints: no text/logos; safe edges; overlay-friendly.

## Where to set style

- `Gemini::AvatarImageSuiteService` accepts `style_profile:`
- `Gemini::AvatarPromptService::DEFAULT_STYLE_PROFILE` defines the default
- We can store a per-profile preferred `style_profile` when needed and pass it through the pipeline

## Suggested presets

- Animated Sitcom: yellow-toned, bold outlines, playful proportions
- Comic Hero: dynamic lighting, halftone textures, bold shadows
- Synthwave Neon: luminous gradients, retro-futuristic shapes
- Minimal Geometric: flat shapes, soft gradients, tech motifs
- Mascot Cat: playful feline silhouette with tech symbolism (no logos)

## Usage

- In Settings: expose a select for Style with safe presets; default to brand style
- In Ops: allow override when re-generating assets

## Prompt hygiene

- Keep structured description intact; append style guidance after core subject description
- Cap length and avoid model confusion (overly long prompts)
- Validate outputs and retry with adjusted guidance if needed
