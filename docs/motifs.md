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

### Images not showing or showing as broken

Run the verification task to check all motif image URLs:

```bash
bin/rails motifs:verify_images
```

This will:

- Check all database URLs for validity
- Verify asset files exist
- Report which motifs will use placeholder images

To automatically fix broken URLs:

```bash
bin/rails motifs:verify_images FIX=1
```

To see a complete list of all motif image sources:

```bash
bin/rails motifs:list_images
```

### Common causes of broken images

1. **Invalid database URLs**: Run `motifs:verify_images FIX=1` to clear them
2. **Missing asset files**: Images should be in:
   - `app/assets/images/archetypes/{slug}.{png|jpg|jpeg|webp}`
   - `app/assets/images/spirit-animals/{slug}.{png|jpg|jpeg|webp}`
3. **Asset precompilation issues**: In production, run:
   ```bash
   bin/kamal app exec "SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile"
   ```
4. **Browser caching**: Clear browser cache or test in incognito mode

### Lore not generating

- Verify Gemini credentials and provider in `config/credentials.yml.enc`
- Check logs for API errors: `bin/kamal app logs | grep -i gemini`
  - Review logs for `generate_missing_lore` Ops action
