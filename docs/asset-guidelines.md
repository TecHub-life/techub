# Asset guidelines

- Primary: `image_processing` + `ruby-vips` (progressive JPEG, strip metadata)

## Definitions

- Avatar: 1x1 image shown in cards; default is the user's GitHub avatar. When the user selects AI avatar, we use an AI 1x1 if present; otherwise we deterministically select from `app/assets/images/avatars-1x1/*`.
- Supporting artwork: background art behind the card content. Default is a deterministic pick from `app/assets/images/supporting-art-1x1/*` based on login. When AI art is explicitly chosen and available, we may use generated assets; otherwise we fall back to the library.

## Locations

- Pre-defined avatars: `app/assets/images/avatars-1x1/`
- Pre-defined supporting art: `app/assets/images/supporting-art-1x1/`

## Selection policy

- AI art is off by default (feature taped). Unless `ai_art_opt_in` is true, all backgrounds use the supporting art library and avatars use the real GitHub avatar.
- If `avatar_choice == 'ai'` and `ai_art_opt_in == true`:
  - Prefer recorded `avatar_1x1` asset; fallback to the avatars library.
- Backgrounds (OG/Card/Simple/Banner):
  - Prefer library art unless the respective `bg_choice_*` is explicitly set to `ai` and `ai_art_opt_in` is true.

## Dimensions and reuse

- Reuse layouts for identical dimensions; avoid redundant views. Prefer:
  - 1200x630 → OG
  - 1280x720 → Card/Simple base
  - 1500x500 → Banner and X header
  - 1080x1080 → Square social (X profile, FB post, IG square)
