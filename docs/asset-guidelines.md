Asset Guidelines (Sizes, Formats, Customization)

Overview

This document captures the recommended canvas sizes, formats, and planned customization controls for
TecHub cards and images.

Asset Types

- OG image (share card)
  - Size: 1200 x 630
  - Aspect: ~1.91:1 (Open Graph standard)
  - Format: image/jpeg (progressive, q≈85); PNG only if transparency is strictly required
  - Target size: aim ≤ 300 KB (the optimizer background threshold)

- Card (main card preview)
  - Size: 1280 x 720
  - Aspect: 16:9
  - Format: image/jpeg (progressive, q≈85)
  - Target size: aim ≤ 350 KB (optimize via vips; automatic background optimization for large files)

- Simple (simplified card)
  - Size: 1280 x 720
  - Aspect: 16:9
  - Format: image/jpeg (progressive, q≈85)
  - Target size: aim ≤ 350 KB

Locations & Names

- Local (dev/prod): `public/generated/<login>/`
  - `og.jpg` (or `og.png` when PNG), `card.jpg`, `simple.jpg`
  - Background candidates (planned): `backgrounds/<kind>-<timestamp>.jpg`
- Spaces (CDN via Active Storage): `generated/<login>/` with public URLs; OG route redirects when
  available

Optimization

- Primary: `image_processing` + `ruby-vips` (progressive JPEG, strip metadata)
- Fallback: ImageMagick CLI (`magick`) with `-interlace Plane` for progressive JPEG
- Background job: runs for larger files (threshold via `IMAGE_OPT_BG_THRESHOLD`, default 300_000
  bytes)

Customization (planned owner controls)

- Per‑variant palette and text color selections exposed in Profile Settings
- Stored alongside the profile card’s theme/style fields; used by the templates for consistent
  renders
- Background selection (choose from multiple generated backgrounds) — see
  `docs/background-selection.md`

Notes

- Screenshots default to JPEG; test environment uses PNG for fixture stability
- OG meta tags on profile pages prefer the CDN URL when uploaded, falling back to local
  `/generated/<login>/og.jpg`
