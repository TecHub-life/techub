Card Layouts & Data Reference

Purpose

- Provide a concise map of what raw and AI-generated data exists and how each card layout uses it.
- Serve as a checklist when adding or tweaking content on Cards/OG/Simple.

Canonical Example (realistic fields)

{ "profile": { "login": "loftwah", "name": "Dean Lofts", "bio": "DevOps Engineer, Music Producer,
and big fan of Open Source.", "location": "Melbourne, Australia", "blog":
"https://linkarooie.com/loftwah", "twitter_username": "loftwah", "avatar_url":
"/avatars/loftwah.png", "github_url": "https://github.com/loftwah", "public_repos": 356,
"public_gists": 633, "followers": 1149, "following": 526 }, "summary": "Ships in public with 356
repositories and 1149 followers...", "languages": [ { "name": "Ruby", "count": 21 }, { "name":
"Shell", "count": 18 }, { "name": "Python", "count": 17 } ], "social_accounts": [ { "provider":
"TWITTER", "url": "https://x.com/loftwah", "display_name": "@loftwah" } ], "organizations": [ {
"login": "TecHub-life", "description": "TecHub is an AI powered profile generator and card game with
leaderboards." } ], "top_repositories": [ { "name": "linux-for-pirates", "language": "Astro",
"stargazers_count": 142 }, { "name": "loftwahs-cheatsheet", "stargazers_count": 42 } ],
"pinned_repositories": [ { "name": "techub", "language": "Ruby", "stargazers_count": 13 } ],
"active_repositories": [ { "name": "techub", "full_name": "TecHub-life/techub", "stargazers_count":
13 } ], "recent_activity": { "total_events": 300, "event_breakdown": { "PushEvent": 131,
"PullRequestEvent": 29 } }, "readme": { "content": "# Dean Lofts ..." }, "card": { "title": "Dean
Lofts", "tagline": "From infrastructure code to generative soundscapes, Dean Lofts builds the
future", "short_bio": "Highly active DevOps Engineer and Cloud Architect...", "long_bio": "Dean
Lofts, a Senior DevOps Engineer and Cloud Architect ...", "buff": "Architect Of Automation",
"buff_description": "Design and implement robust, automated infrastructure and creative systems...",
"weakness": "Sprawling Innovation", "weakness_description": "Relentless drive can spread focus
across many projects...", "flavor_text": "From infrastructure code to generative soundscapes, Dean
Lofts builds the future", "attack": 100, "defense": 100, "speed": 75, "playing_card": "Ace of ♣",
"spirit_animal": "Koala", "archetype": "The Hero", "vibe": "Open Source", "vibe_description":
"Orchestrates complex cloud environments with community spirit...", "special_move": "Community
Rally", "special_move_description": "Rapidly deploys AI‑driven platforms and resilient cloud
architectures...", "tags": ["ruby","shell","python","devops","hacktoberfest","linux"] } }

Data Inventory

- Raw Profile (GitHub-derived)
  - identity: `login`, `display_name`, `avatar_url`, `bio`, `summary`
  - social: `followers`, `public_repos`, `hireable`, `location`, `company`
  - repos: `top_repositories[]` (name, stargazers_count, topics_list), `active_repositories[]`
  - languages: `profile_languages[]` (name, count)
  - orgs: `profile_organizations[]` (login, name)
  - activity: `profile_activity.total_events` (window determined by pipeline)
  - images (generated/uploads): `public/generated/:login/*`

- AI / Synthesis (ProfileCard)
  - identity: `title`, `tagline` (short, punchy line)
  - bios: `short_bio` (concise paragraph), `long_bio` (multi‑paragraph)
  - stats: `attack`, `defense`, `speed` (0..100)
  - traits: `vibe`, `special_move`, `spirit_animal`, `archetype`, `playing_card`
  - tags: `tags[]` (array, normalized to lowercase in UI)
  - style/theme: `style_profile`, `theme`, `generated_at`
  - background prefs: `bg_choice_card|og|simple` in `profile_card` (ai | default | color),
    `bg_color_card|og|simple`

- Assets (ProfileAssets)
  - kinds: `og`, `card`, `simple`, `avatar_3x1` (3×1 banner), `avatar_16x9` (16:9 art)
  - fields: `public_url`, `local_path`, `provider`, `mime_type`

Layout Specs

- Main Card (HTML view: `GET /cards/:login/card`)
  - size: 1280×720 (16:9)
  - header ratio: 30/70 (banner:content)
  - layout: 3‑column lower grid → `[avatar gutter | main content | meta chips]`
  - background: full image (light gradient for legibility)
  - shows
    - name + handle
    - single URL chip (blog preferred; else GitHub) and location
    - flavor_text (quoted) then short_bio (no truncation)
    - right column: ⭐ stars • 👥 followers, 📦 repos, ATK/DEF/SPD, spirit_animal, archetype,
      Vibe/Move/Buff/Weak
  - tags: centered below grid (all 6)
  - corners: playing_card marker (full text) top‑right of banner and bottom‑left of card
  - removed: repo chips, languages, progress bars

- OG Image (HTML view: `GET /cards/:login/og`)
  - size: 1200×630
  - background: darker (image opacity ~0.28) + strong gradient
  - shows
    - name + handle
    - one‑line tagline: `flavor_text` → `short_bio` (quoted)
    - top repo chips (name + ★ count)
    - card chips: ATK/DEF/SPD, spirit_animal, archetype
    - tag chips (all 6)
    - meta: URL (blog preferred, else GitHub) + "⭐ stars • 👥 followers"
  - corners: playing_card (full text) at top‑right and bottom‑left

- Simple (HTML view: `GET /cards/:login/simple`)
  - size: 1280×720 (16:9)
  - background: image opacity ~0.10 + soft radial vignette (content above overlay)
  - shows
    - avatar (ring), name, handle
    - single URL chip (blog preferred; else GitHub)
    - ATK/DEF/SPD and playing_card/spirit_animal/archetype
    - tags (all 6), centered

Settings Page Previews

- Path: `/my/profiles/:username/settings`
  - inline scaled iframes for Card, OG, Simple
  - “Open full view” links to actual routes for screenshotting
  - upload slots for `card`, `og`, `simple`, and banner `avatar_3x1`

Design Notes & Guidelines

- Backgrounds
  - keep abstract; no text/logos; avoid literal portraits on 3×1/16:9 unless explicitly desired
  - opacity subdued on Card/OG/Simple to prioritize content legibility

- Chips & Casing
  - languages and `tags[]` render in lowercase (normalized in views)
  - repo chips prefer concise repository names over verbose metrics

- Content Priorities
  - main card: identity + URLs → flavor_text + short_bio → right‑column chips → tags
  - og: identity → tagline (1‑line) → repo chips → stat/trait chips → tags
  - simple: identity + URL → stat/trait chips → tags

Where to Change Things

- Views (layouts and chips)
  - Main card: `app/views/cards/card.html.erb`
  - OG: `app/views/cards/og.html.erb`
  - Simple: `app/views/cards/simple.html.erb`
  - Settings previews: `app/views/my_profiles/settings.html.erb`

- Data synthesis
  - Card fields: `app/services/profiles/synthesize_card_service.rb`
  - Avatar prompts and constraints: `app/services/gemini/avatar_prompt_service.rb`

Quick Checks

- Run HTML previews:
  - `/cards/:login/card`, `/cards/:login/og`, `/cards/:login/simple`
- Verify assets present under: `public/generated/:login/`
- Ensure `ProfileCard` exists for the profile for full chips set

Layout Consumption Map (exact fields)

- Main Card
  - identity: `profile.name`, `profile.login`
  - meta chips: `profile.github_url` (from `html_url`), `profile.location`, `profile.followers`
  - tagline: `card.tagline` → `card.short_bio` → `profile.bio` (target ≤ 80 chars; 2 lines via
    line‑clamp)
  - repo chips: `top_repositories[].name` + `stargazers_count` (★ shown if > 0)
  - languages: `languages[].name` (lowercase)
  - stat/trait chips: `card.attack`, `card.defense`, `card.speed`, `card.playing_card`,
    `card.spirit_animal`, `card.archetype`
  - fanfare: spirit animal and archetype chips styled with distinct colors/icons
  - trait descriptions: `card.vibe` + `vibe_description`, `card.special_move` +
    `special_move_description`, `card.buff` + `buff_description`, `card.weakness` +
    `weakness_description`
  - tags: `card.tags[]` (lowercase)
  - corners: playing card marker from `playing_card` at top‑right and bottom‑left (full text)

- OG Image
  - identity: `profile.name`, `profile.login`
  - repo chips: `top_repositories[].name` + `stargazers_count`
  - languages: `languages[].name` (lowercase)
  - stat/trait chips: `card.attack`, `card.defense`, `card.speed`, `card.playing_card`,
    `card.spirit_animal`, `card.archetype`
  - tags: `card.tags[]` (lowercase)
  - no bio text to avoid clutter

- Simple Image
  - identity: `profile.name`, `profile.login`, avatar
  - languages: `languages[].name` (lowercase)
  - stat/trait chips: `card.attack`, `card.defense`, `card.speed`, `card.playing_card`,
    `card.spirit_animal`, `card.archetype`
  - no bio text

Text Fit & No-Clip Rules

- On images, we clamp lines rather than truncate strings; no mid‑word cuts.
- Keep image text short; long narratives belong on the profile page.
- Content remains full opacity; backgrounds are subdued; avoid placing text on high‑contrast areas.

Public Profile Page

- Path: `/profiles/:username`
- Tabs: Profile, Overview, Activity, Stats & Traits
- Current highlights
  - Structured metadata & OG wired (JSON‑LD uses `short_bio` → `bio`).
  - Overview: flavor_text/short_bio banner, stat/trait chips, tags, top languages, social accounts,
    organizations.
  - Activity: recent events and active repositories.
  - Stats & Traits: numeric stats, traits (playing_card, spirit_animal, archetype), tags.
- Should/Planned
  - Hero: show `long_bio` expanded with “read more”; keep `short_bio` as teaser.
  - Traits panel: add `vibe` + `vibe_description`, `special_move` + `special_move_description`,
    `buff` + `buff_description`, and `weakness` + `weakness_description` (full text).
  - Repos: dedicated grids for `pinned_repositories` and `top_repositories` with stars/forks and
    topics.
  - Orgs: richer cards with descriptions and avatars.
  - Social: verified links and badges.
  - Tags cloud: interactive filter to directory.

Tagline and Bios (Exact Rules)

- Sources and generation
  - `tagline`
    - v1 deterministic: derived from `Profile.summary` then `Profile.bio`, truncated to 80 chars.
      - Code: `app/services/profiles/synthesize_card_service.rb`:95 and :100
    - v2 AI (if enabled): updated from AI `flavor_text` when present; else leaves existing.
      - Code: `app/services/profiles/synthesize_ai_profile_service.rb`:76
  - `short_bio`
    - AI‑generated concise paragraph (target 180–220 chars; third person; no emojis).
      - Columns added in migration: `db/migrate/20251014010000_add_ai_fields_to_profile_cards.rb`
      - Code: `app/services/profiles/synthesize_ai_profile_service.rb`:77
  - `long_bio`
    - AI‑generated long narrative (target 600–900 chars; third person; concrete).
      - Columns added in migration: `db/migrate/20251014010000_add_ai_fields_to_profile_cards.rb`
      - Code: `app/services/profiles/synthesize_ai_profile_service.rb`:78

- Display precedence per view
  - Main Card (`/cards/:login/card`)
    - Use: `ProfileCard.short_bio` → `Profile.bio` (no truncation). `flavor_text` is displayed above
      as a quoted line.
    - Code: `app/views/cards/card.html.erb`
  - OG (`/cards/:login/og` / `/og/:login.jpg`)
    - One‑line: `flavor_text` → `short_bio` (quoted, clamped)
  - Simple (`/cards/:login/simple`)
    - No biography text; minimal identity + chips.

- Other places bios are used
  - Profile page hero: long form preference `long_bio` → `short_bio` → `bio`.
    - Code: `app/views/profiles/tabs/_hero.html.erb`:16
  - Overview tab quote: uses `flavor_text` (aka tagline) or `short_bio`.
    - Code: `app/views/profiles/tabs/_overview.html.erb`:6
  - Profiles JSON: includes `tagline`, `short_bio`, `long_bio` when present.
    - Code: `app/controllers/profiles_controller.rb`:105
