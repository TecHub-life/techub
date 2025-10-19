# ADR-0005: Image generation model strategy — Gemini Native ("Nano Banana") vs Imagen

## Status

Accepted

## Date

2025-10-19

## Context

We generate AI artwork for user profile cards and related assets. Google’s Gemini API offers two
relevant image paths:

- Gemini Native Image generation (aka "Nano Banana") — conversational, multi-turn editing, strong
  flexibility
- Imagen — specialized, photorealism-oriented image generator

Docs indicate: Gemini supports text-to-image with `contents` and returns base64 inlineData. Imagen
is available via the same API with different strengths and pricing. Aspect ratio is set via
`generationConfig.aspectRatio` (or provider-specific casing) rather than an explicit width/height.
References: [Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation),
[Imagen](https://ai.google.dev/gemini-api/docs/imagen).

Our system currently:

- Targets `gemini-2.5-flash-image` by default
- Supports both AI Studio (API key) and Vertex endpoints
- Sends `contents` with a single text part and `generationConfig` including `aspectRatio` when
  enabled
- Extracts base64 image data via `candidates[0].content.parts[].inlineData.data`
- Post-processes to JPEG by default for size and performance

## Decision

- Default to Gemini Native Image generation ("Nano Banana") for all avatar and background variants.
- Keep the provider abstraction, allowing Imagen to be toggled per-variant in the future when higher
  photorealism or typography precision is required.
- Continue passing `aspectRatio` in generation config and handling conversion/cropping in
  post-processing.
- Maintain multi-variant generation (1x1, 16:9, 3:1, 9:16) for flexible placements, and layer
  social-specific sizes via post-process resize/crop rather than direct model generation of every
  resolution.

## Rationale

- Gemini Native provides conversational editing and broad flexibility that matches our product’s
  iterative art direction.
- Imagen may yield higher fidelity for specific tasks (photorealism, typography) but is not
  essential for our current UX; preserving the abstraction lets us adopt Imagen selectively without
  refactors.
- Post-processing to exact social sizes keeps generation costs low and reuse high.

## Consequences

Positive:

- Consistent defaults and simpler ops; fewer model toggles for most users
- Clear path to adopt Imagen for select cases without breaking changes
- Cost control via generating few AR variants and resizing locally

Trade-offs:

- Some use-cases (e.g., perfect text in-image) may benefit from Imagen; we will opt-in case-by-case
- Relying on post-process resizing can slightly reduce fidelity compared to native-size generation,
  but is acceptable for social distribution

## References

- Gemini Image Generation: https://ai.google.dev/gemini-api/docs/image-generation
- Imagen via Gemini API: https://ai.google.dev/gemini-api/docs/imagen
- Social sizes reference (guidance):
  https://sproutsocial.com/insights/social-media-image-sizes-guide/

## Review Date

2026-01-15

## Decision Makers

- Engineering + Product

## Related ADRs

- ADR-0002: Screenshot generation driver — Node Puppeteer
- ADR-0001: LLM cost control via eligibility gate

## Implementation Status

- Implemented: Gemini Native generation and multi-variant pipeline
- Planned: Social-size post-process outputs and UI/ops toggles
