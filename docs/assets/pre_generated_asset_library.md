# Pre-generated asset library (topics/tags)

We will ship a curated library of AI-generated backgrounds and motifs relevant to common developer
topics. Users can pick from this library instead of (or before) generating custom images.

## Goals

- Provide high-quality defaults for fast onboarding
- Cover common topics/tags (see Popular Tags list)
- Keep outputs safe-edge and overlay-friendly (no text/logos)

## Sources and prompts

- Use `Gemini::AvatarImageSuiteService` with non-portrait prompts that emphasize abstract symbolic
  motifs per topic.
- Variants: 16:9 and 3:1 prioritized; 1x1 for avatars where appropriate (non-portrait emblematic
  styles only).
- Style: match brand (TecHub) and maintain consistent palette families.

## Storage & naming

- Directory: `public/library/<topic>/`
- Filenames: `<topic>-<variant>-v<seq>.jpg` (e.g., `python-16x9-v1.jpg`, `security-3x1-v2.jpg`)
- Optional metadata JSON per topic with palette notes and usage guidance

## Surfacing in product

- Settings: "Pick from library" selector with topic filters and previews
- Card builders: quick-pick rows for 16:9 (OG) and 3:1 (banner)
- Ops: bulk refresh or extend library with new variants

## Governance

- Only abstract/symbolic art, no faces, no text/logos
- Review queue for additions; keep 3–5 strong options per topic
- Periodic pruning of underused assets
