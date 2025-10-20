## Supported social asset sizes

We produce post‑processed social assets from the AI avatar variants (1:1, 3:1, 16:9, 9:16).

- X (Twitter)
  - x_profile_400 → 400×400 (src: avatar_1x1)
  - x_header_1500x500 → 1500×500 (src: avatar_3x1)
  - x_feed_1600x900 → 1600×900 (src: avatar_16x9)
- Instagram
  - ig_square_1080 → 1080×1080 (src: avatar_1x1)
  - ig_portrait_1080x1350 → 1080×1350 (src: avatar_9x16)
  - ig_landscape_1080x566 → 1080×566 (src: avatar_16x9)
- Facebook
  - fb_cover_851x315 → 851×315 (src: avatar_16x9)
  - fb_post_1080 → 1080×1080 (src: avatar_1x1)
- LinkedIn
  - linkedin_cover_1584x396 → 1584×396 (src: avatar_3x1)
  - linkedin_profile_400 → 400×400 (src: avatar_1x1)
- YouTube
  - youtube_cover_2560x1440 → 2560×1440 (src: avatar_16x9)
- OpenGraph (generic)
  - og_1200x630 → 1200×630 (src: avatar_16x9)

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
- Capture card views (og, card, simple, banner) via Puppeteer.
- Post-process social sizes from AI variants.
- Expose assets via `/api/v1/profiles/:username/assets`.
