# PR: Settings UX Polish, Avatar Toggle, Crop/Zoom, Aspect Hints

Summary

Improve owner Settings with simple, safe controls and wire them through to renders. Add an env‑gated
aspect ratio hint for AI image gen. Keep everything observable.

Included Changes

- Avatar choice (real vs AI) persisted on `profile_cards.avatar_choice` and used by Card/OG/Simple
  renders.
- Background crop/zoom controls per variant (Card/OG/Simple) with a one‑click “Use Everywhere”
  propagation.
- Reroll (AI regenerate) countdown text on Settings.
- Aspect ratio hint added to Gemini image generation payload (env‑gated; prompt hint kept).
- Structured log on Settings save (`settings_updated`).
- Tests: helper unit tests; service test for aspect ratio hint.

Files

- Migration: `db/migrate/20251019000004_add_avatar_choice_to_profile_cards.rb`
- Controller: `app/controllers/my_profiles_controller.rb`
- Views: `app/views/my_profiles/settings.html.erb`, `app/views/cards/card.html.erb`,
  `app/views/cards/og.html.erb`, `app/views/cards/simple.html.erb`
- Helper: `app/helpers/cards_helper.rb`
- Gemini: `app/services/gemini/image_generation_service.rb`
- Tests: `test/helpers/cards_helper_test.rb`,
  `test/services/gemini/image_generation_service_test.rb`

Flags & Config

- `GEMINI_INCLUDE_ASPECT_HINT` (default ON). Set to `0`/`false` to disable adding `aspectRatio` to
  the provider payload.

Validation

- Migrate DB: `bin/rails db:migrate`.
- Run tests: `bin/ci` (or `bundle exec rails test`).
- Settings → Avatar Selection: choose AI, verify AI avatar shows if `avatar_1x1` exists; else
  fallback to GitHub avatar.
- Settings → Background Selection: tweak Card Crop X/Y/Zoom → Card preview updates. Tick “Use
  Everywhere” → OG + Simple adopt same crop/zoom.
- Reroll button shows countdown when unavailable.
- Optional: export `GEMINI_INCLUDE_ASPECT_HINT=1`, run an image gen task; logs/artifacts should
  include the ratio hint in payload.

Notes

- No profile page edits; scoped to Settings and render templates.
- Aspect ratio hint is provider‑specific and gated; prompt hints remain as a fallback.
- Logging uses `StructuredLogger` to keep observability consistent.
