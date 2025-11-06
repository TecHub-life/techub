# AI Profile Tuning Notes

This note captures where TecHub pulls profile signals today, why battle stats can feel off, and the
guardrails we just added so future tweaks do not break the public JSON consumed by TecHub Battles.

---

## Current data flow (code refs)

- GitHub ingest: `Profiles::GeneratePipelineService` orchestrates stages that call
  `Github::ProfileSummaryService` and persist results
  (`app/services/profiles/generate_pipeline_service.rb`).
- Heuristic card synthesis: `Profiles::SynthesizeCardService` computes base stats using followers,
  repo stars, organisations, and activity (`app/services/profiles/synthesize_card_service.rb`).
- Gemini-powered traits: `Profiles::SynthesizeAiProfileService` asks Gemini 2.5 Flash for the full
  JSON bundle, then clamps/normalises values before saving to `ProfileCard`
  (`app/services/profiles/synthesize_ai_profile_service.rb`).
- API surface: `/api/v1/profiles/:username`, `/api/v1/profiles/battle-ready`, and
  `/api/v1/profiles/:username/assets` (`app/controllers/api/v1/profiles_controller.rb`).

---

## Observed pain points

- **Flat stat ranges:** Attack/defense/speed are clamped to 60-99 and currently depend on absolute
  follower/star counts (`SynthesizeAiProfileService#validate_and_normalize`). High-signal users
  cluster near the ceiling and new profiles can jump straight to the 70s.
- **Limited activity impact:** `Profiles::SynthesizeCardService#compute_from_signals` considers
  `ProfileActivity.total_events` but ignores streak metrics and contribution breakdowns we already
  persist from GraphQL.
- **Generic bios:** Gemini has minimal guidance beyond “long_bio”/“short_bio”. The system prompt
  does not steer toward concrete GitHub achievements, yielding filler sentences.
- **Spirit animal / archetype drift:** Without strong overrides the model still occasionally picks
  outside the allowlists, triggering strict re-asks and adding latency.

---

## Safeguards in place (do not remove)

- Added controller tests that lock the public JSON schema for `card` and `battle_ready`
  (`test/controllers/api/v1/battles/profiles_controller_test.rb`). Any future change must keep these
  keys intact so TecHub Battles stays compatible while the main `/api/v1/profiles/...` endpoints can
  evolve.
- Documentation now shows the exact Gemini REST payloads for text-to-image, editing, multi-image
  composition, structured output, image descriptions, and URL context (`docs/gemini-setup.md`).
- AI cost docs highlight that editing/multi-image flows add input tokens per reference
  (`docs/ai-costs-and-usage.md`), guarding against runaway spend.

---

## Next-step tuning ideas (non-breaking additions)

1. **Normalise stats relative to cohort**
   - Compute percentiles/z-scores for followers, star sum, contribution streaks, and total events.
   - Feed those into `SynthesizeAiProfileService#build_context` so Gemini has richer signals.
   - Backstop with a post-processing step that re-scales attack/defense/speed to 60-99 using
     percentile buckets instead of raw counts.
2. **Enrich activity context**
   - Pass contribution stats (`ProfileActivity#activity_metrics`) into the prompt with explicit
     hints (“recent streak: 15 days”).
   - Surface recent repo names with concise descriptors so bios stay grounded.
3. **Prompt refinements**
   - Update `system_prompt` to require that `short_bio` references at least one concrete repo or
     metric.
   - Add “balance guidance” bullet so Gemini spreads attack/defense/speed (e.g., “interpret stats as
     trade-offs; do not set all three above 90 unless signals are exceptional”).
   - Tweak `strict_system_prompt` to hard-fail if tags repeat domains we already supply (e.g.,
     “builder”).
4. **Structured validation**
   - Introduce a lint step that re-validates generated cards against rolling averages and flags out
     of band stats for manual review (store metadata via `Profiles::PipelineDoctorService`).
5. **Optional: reference image hooks**
   - Extend `Gemini::ImageGenerationService` with editing/multi-image payload builders so ops can
     selectively restyle avatars without hitting manual curl scripts.

None of the above require changes to the existing JSON contract; they either add context before the
Gemini call or post-process fields that already exist.

---

## Checklist before shipping improvements

- [ ] Update or add tests that cover any newly surfaced fields (keep existing ones untouched).
- [ ] Re-run `bundle exec rails test test/controllers/api/v1/profiles_controller_test.rb`.
- [ ] Capture before/after examples in `public/generated/<login>/meta/` and attach to the PR so ops
      can compare.
- [ ] Document prompt changes under `docs/gemini-setup.md` to keep the reference in sync.
