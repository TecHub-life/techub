OG Image and Card Views

Dimensions and MIME Types

- OpenGraph: 1200x630 (1.91:1). MIME: image/png (or image/jpeg). We use PNG.
- TecHub Card: 1280x720 (16:9). MIME: image/png.
- Simplified Card: 1280x720 (16:9). MIME: image/png.

Routes (HTML, sized for screenshots)

- /cards/:login/og → 1200x630 preview
- /cards/:login/card → 1280x720 card preview
- /cards/:login/simple → 1280x720 simplified card

Usage

- Views render fixed-size containers using Tailwind (e.g., w-[1200px] h-[630px]).
- A future screenshot worker (Playwright/Puppeteer) captures these routes to PNG.
- In development, assets (including generated images) stay on disk.

Screenshots (Puppeteer)

- Script: `script/screenshot.js` (requires `puppeteer` devDependency)
- Rails service: `Screenshots::CaptureCardService` shells out to Node and returns `ServiceResult`.
- Rake: `rake "screenshots:capture[login,variant]"` with optional `APP_HOST` and `out` path.
- Example:
  - `APP_HOST=http://127.0.0.1:3000 rake "screenshots:capture[loftwah,og]"`
  - Saves to `public/generated/loftwah/og.png` by default.

Design Notes

- Based on TechDeck layout patterns, adapted for GitHub profiles (name, login, followers, location,
  top languages, bio, avatar).
- Keep text legible within the fixed frame; long names scale down.

Future PRs

- Screenshot worker to render routes to PNG and store them (PNG mime).
- OG image route that serves the PNG directly for meta tags.

### Optimization

- We use ImageMagick to optimize outputs.
- Service: strips metadata and compresses PNG; JPEGs use by default.
- Rake: (e.g., ).
- Dockerfile installs for production usage.

Tip: keep OG as PNG or export as high-quality JPEG if size is critical. Use ProfileAsset entries to
track current paths/URLs.
