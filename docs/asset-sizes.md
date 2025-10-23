## Supported asset sizes

TecHub currently produces two families of artwork:

**Card captures**

- `og` → 1200×630 (TecHub OG preview)
- `card` → 1280×720 (main trading card)
- `simple` → 1280×720 (minimal layout)
- `banner` → 1500×500 (header / cover art)

**Social-ready crops**

- `x_profile_400` → 400×400 (square avatar)
- `fb_post_1080` → 1080×1080 (square post)
- `ig_portrait_1080x1350` → 1080×1350 (portrait post)

Reference: Sprout Social image sizes guide:
https://sproutsocial.com/insights/social-media-image-sizes-guide/

### When to use card views vs AI art

- Use card views when:
  - You need TecHub-branded composition, text overlays, UI framing, or a consistent layout (og,
    card, simple, banner).
  - You want to change the layout globally without re-running AI — screenshots regenerate on demand.
- Use AI art when:
  - You need raw, stylized artwork in standard aspect ratios that can be repurposed across networks.
  - You’ll derive many crops/sizes cheaply post-process without extra AI cost.

Workflow

- Generate AI avatar variants (1:1, 3:1, 16:9, 9:16).
- Capture card views (`og`, `card`, `simple`, `banner`) via Puppeteer.
- Post-process social sizes (`x_profile_400`, `fb_post_1080`, `ig_portrait_1080x1350`) from AI
  variants.
- Expose assets via `/api/v1/profiles/:username/assets`.
