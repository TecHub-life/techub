Card Synthesis (Profile → ProfileCard)

Overview

- Service: `Profiles::SynthesizeCardService` computes card attributes from existing profile signals
  and returns a `ServiceResult`.
- Persisted model: `ProfileCard` (one per Profile), with stats (attack/defense/speed), vibe,
  special_move, spirit_animal, archetype, tags, style_profile, and theme.

How it works (v1)

- Signals used: followers, public repos, account age, top repo stars, active repos, recent events,
  top languages.
- Deterministic formula maps signals → 0..100 stats.
- Simple heuristics derive vibe/special_move/archetype; style_profile defaults to our TecHub style.
- Safe defaults; no network calls.

Usage

- Persist a card:
  - `bundle exec rake "profiles:card[loftwah]"`
- Non-persisted preview (controller can use this pattern):
  - `Profiles::SynthesizeCardService.call(profile: profile, persist: false)`

Fields

- `title`, `tagline`
- `attack`, `defense`, `speed` (0..100)
- `vibe`, `special_move`, `spirit_animal`, `archetype`
- `tags` (array), `style_profile`, `theme`, `generated_at`

Next (AI-enhanced v2)

- Use Gemini to produce structured card data with validation loop; keep deterministic fallback.
- Background job to refresh cards periodically.
