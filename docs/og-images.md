# OG images

- Defaults: background from supporting art library; avatar from GitHub.
- Library paths:
  - Avatars: `app/assets/images/avatars-1x1/`
  - Supporting art: `app/assets/images/supporting-art-1x1/`
- Overrides:
  - Backgrounds can be set to 'ai' explicitly when `ai_art_opt_in` is on.
  - Avatars can be set to 'ai'; we prefer an existing AI asset and fallback to avatars library.

OG Images — Generation & Serving

Optimal Sizes & Formats

- OG: 1200x630, progressive JPEG (q≈85) preferred
- Card: 1280x720, progressive JPEG (q≈85)
- Simple: 1280x720, progressive JPEG (q≈85)
- PNG is reserved for transparency‑required cases only

Dimensions and MIME Types

- OpenGraph: 1200x630 (1.91:1). MIME: image/jpeg preferred (progressive); PNG fallback.
- TecHub Card: 1280x720 (16:9). MIME: image/jpeg.
- Simplified Card: 1280x720 (16:9). MIME: image/jpeg.

Routes (HTML, sized for screenshots)

- /cards/:login/og → 1200x630 preview
- /cards/:login/card → 1280x720 card preview
- /cards/:login/simple → 1280x720 simplified card

Screenshots (Puppeteer)

- Script: `script/screenshot.js` (uses `puppeteer`)
- Service: `Screenshots::CaptureCardService` shells out to Node and returns `ServiceResult`.
- Output defaults to JPEG (q=85); test env uses PNG for fixture stability.

Optimization

- `Images::OptimizeService` uses `image_processing` + `ruby-vips` (progressive JPEG, strip metadata)
  with ImageMagick fallback.
- Background job `Images::OptimizeJob` handles larger assets and optional upload to Spaces.

Direct Route

- `/og/:login(.:format)` (default format: `jpg`).
- Behaviour:
  - If a CDN/public URL exists for `kind: 'og'`, responds with a 302 redirect to that URL.
  - Else if a local file exists under `public/generated/:login/og.jpg` (or `.png`), serves it with
    `Cache-Control: public, max-age=31536000`.
  - Else enqueues `Profiles::GeneratePipelineJob` and responds `202 Accepted` with
    `{ status: 'generating' }`.

Meta Tags

- Profile pages set `og:image` and Twitter image tags, preferring CDN URLs when available.

See also

- `docs/asset-guidelines.md` for sizes, formats, locations, and customization notes
