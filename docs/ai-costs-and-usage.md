# AI costs and usage planning

This doc estimates image generation costs and levers to control spend.

## Assumptions

- Gemini Native Image pricing per docs: image output tokenized at ~1290 tokens/image (≤1024x1024),
  billed at ~$30 per 1M tokens.
- We generate via `gemini-2.5-flash-image` with aspect ratios (1x1, 16:9, 3:1, 9:16). Post-process
  to social sizes locally.

## Per-image estimate

- 1290 tokens/image ≈ $0.0387 per image
- 1k images ≈ 1.29M tokens ≈ $38.7

## Example scenarios

- 1,000 users × 4 variants = 4,000 images → ~5.16M tokens → ~$155
- 1,000 users × 2 variants = 2,000 images → ~2.58M tokens → ~$77

## Controls

- Eligibility gate: only generate for profiles above a threshold (already implemented)
- On-demand generation: expose toggles in Settings/Ops (already in plan)
- Reuse/caching: avoid re-generating when prompts haven’t changed
- Scheduled batches: off-peak generation to smooth load
- Post-processing: derive social sizes via local resize (no extra tokens)

## Monitoring

- Track generation counts and provider metadata in logs (StructuredLogger)
- Send logs to Axiom and build cost dashboards

## Future

- Add provider switch per variant; test Imagen case-by-case for typography/photoreal needs
