# Motifs (Archetypes & Spirit Animals)

This document explains how motifs are managed (artwork and lore), how to seed them, and how to
auto‑generate missing lore.

## Where motifs appear

- Public pages: `/archetypes`, `/spirit-animals`, and the Directory filters
- Profiles: archetype/spirit values are set on the card when generated
- Ops: `/ops/motifs` for CRUD, uploads, and bulk actions

## Artwork sources and fallbacks

Artwork is resolved in this order:

1. Database URL (`Motif.image_1x1_url`) if set via Ops Motifs editor
2. Asset pipeline by slug:
   - `app/assets/images/spirit-animals/{slug}.{png|jpg|jpeg|webp}`
   - `app/assets/images/archetypes/{slug}.{png|jpg|jpeg|webp}`
3. Placeholder: `app/assets/images/android-chrome-512x512.jpg`

Slug is derived from the name (`Motifs::Catalog.to_slug`). Example: “Great White Shark” →
`great-white-shark`.

## Ops Motifs panel

- Create/Edit/Delete motifs
- Upload 1×1 artwork (or paste a URL)
- Edit short and long lore
- Bulk actions:
  - Seed from Catalog (with optional Overwrite)
  - Generate Missing Lore (Gemini) (with optional Overwrite)

## Seeding from catalog

- Via Ops: `/ops/motifs` → “Seed from Catalog”
- Via Rake:

```bash
bin/rails motifs:seed
bin/rails motifs:seed OVERWRITE=1
```

- Seed uses `Motifs::Catalog.*_entries` as the source of names/descriptions
- When Overwrite is enabled, existing names/short_lore are refreshed from catalog

## Generate missing lore (Gemini)

- Via Ops: `/ops/motifs` → “Generate Missing Lore (Gemini)”
  - Check “Overwrite lore” to force regeneration
- Implementation: `Motifs::GenerateLoreService`
  - Calls `Gemini::StructuredOutputService` with a schema producing
    - `short_lore`: ≤ 140 chars, one sentence
    - `long_lore`: 2–4 sentences

Requirements:

- Gemini credentials configured (see `docs/integrations.md`)

## Conventions

- Spirit Animals and Archetypes live under a single `Motif` model (`kind`: `spirit_animal` or
  `archetype`)
- Theme defaults to `core`; future themes can coexist by unique `(kind, slug, theme)`
- New entries can be added to `lib/motifs/catalog.rb` (e.g., `Loftbubu`)

## Troubleshooting

- Thumbnail not showing in Ops/Public pages:
  - Ensure `image_1x1_url` is set, or place an asset at the expected slug path
  - Check the slug matches the filename (lowercase, `-` separator)
- Lore not generating:
  - Verify Gemini credentials and provider
  - Review logs for `generate_missing_lore` Ops action
