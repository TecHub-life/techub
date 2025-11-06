# AI Costs and Usage Planning

This document estimates **AI image generation and text generation costs** for TecHub workloads,
explains how costs scale with user activity, and outlines controls for managing spend.

All figures are **per execution/session**, with **monthly estimates** based on forecasted user
activity.

---

## Assumptions

- **Google AI Studio (Gemini 2.5 Flash) pricing:** Mirrors the public Vertex AI rate card—~1,290
  tokens per 1024×1024 image billed at **$30 per 1M output tokens**. Vertex fallback uses the same
  rate when we need service-account routing.
- **Token-to-cost ratio:** 1M tokens = $30 → 1 token = $0.00003.
- **Variant strategy:** Request **four 1024×1024 profile image variants** per run, then crop or
  resize locally. We avoid relying on aspect ratio parameters until quality improves.
- **Optional avatar seeding:** Passing a GitHub avatar or uploaded photo as image input adds roughly
  1,290 input tokens (≈$0.0004) per reference—cheap enough to experiment with.
- **Editing & multi-image inputs:** Each uploaded reference image counts as ~1,290 input tokens, so
  editing or style transfer flows cost roughly the same as seeding plus the generated output.
- **Session model:** Each user session creates:
  - 4 _Nano Banana_ profile image variants
  - 4 image descriptions (alt text / moderation blurbs)
  - 1 long-form summary
  - 1 structured JSON payload

---

## Per-Image Estimate

| Images Generated | Tokens Used | Approx. Cost (USD) | Notes             |
| ---------------: | ----------: | -----------------: | ----------------- |
|          1 image |       1,290 |            $0.0387 | Single image      |
|     1,000 images |       1.29M |             $38.70 | Baseline test set |
|     4,000 images |       5.16M |            $154.80 | 4 variants/user   |
|    10,000 images |       12.9M |            $387.00 | Monthly example   |

> For TecHub, assume 4 variants per user profile (social, banner, avatar, etc.). If 1,000 users
> generate their profiles once per month → ~$155. If users re-generate monthly (e.g., updated
> archetypes) → ~$155/month.

---

## Cost Controls

- **Eligibility gate:** Only generate for verified or engaged users.
- **On-demand generation:** Users trigger generation manually.
- **Caching:** Skip re-generation when prompt or seed hasn’t changed.
- **Batch scheduling:** Run jobs off-peak to balance compute load.
- **Local post-processing:** Derive resized or social images locally.

---

## Monitoring

- Log every generation event with metadata (model, tokens, userId, type).
- Stream to **Axiom** for real-time spend visibility.
- Tag by `app` and `env` for cross-project cost tracking.

---

## Implementation Notes (AI Studio default, Vertex fallback)

- Route calls through **Google AI Studio** by default; keep Vertex credentials scoped in secrets so
  ops can explicitly enable service-account runs (e.g., when API-key flows are blocked).
- Use feature flags to expose “Generate profile art” and “Describe image” in user settings, with
  mirrored controls inside the Ops panel for moderation.
- Capture the user’s GitHub avatar (if present) as an optional reference asset; store consent and
  provenance for each generation batch.
- Include moderation status in structured outputs so Ops can approve or reject assets before they
  surface publicly.

---

## Gemini 2.5 Flash Workload Snapshot

| Workload                          | Key assumption                                        | Cost per session (USD) |  10 users |  50 users |  150 users |  500 users | 1,000 users |
| --------------------------------- | ----------------------------------------------------- | ---------------------: | --------: | --------: | ---------: | ---------: | ----------: |
| Profile image variants (×4)       | 4 × 1,290 output tokens @ $30/M                       |                $0.1548 |     $1.55 |     $7.74 |     $23.22 |     $77.40 |     $154.80 |
| Image descriptions (×4)           | 4 × (1,440 input + 200 output tokens)                 |                $0.0037 |     $0.04 |     $0.19 |      $0.56 |      $1.86 |       $3.73 |
| Text generation (summary)         | 1,500 input + 700 output tokens                       |                $0.0022 |     $0.02 |     $0.11 |      $0.33 |      $1.10 |       $2.20 |
| Structured output (JSON profile)  | 1,000 input + 400 output tokens                       |                $0.0013 |     $0.01 |     $0.07 |      $0.19 |      $0.65 |       $1.30 |
| **Combined session**              | Sum of the above workloads                            |            **$0.1620** | **$1.62** | **$8.10** | **$24.30** | **$81.01** | **$162.03** |
| Optional avatar seeding (per run) | 1,290 input tokens @ $0.30/M (if we send a reference) |                $0.0004 |     $0.00 |     $0.02 |      $0.06 |      $0.19 |       $0.39 |

---

## Monthly Forecast Scenarios (TecHub)

These models assume **combined session cost = $0.1620 per user per generation** (four image
variants + descriptions + summary + structured payload). You can scale by average monthly
regenerations (sessions/user/month).

| Users | Sessions per User (Monthly) | Total Sessions | Est. Monthly Cost (USD) |
| ----: | --------------------------: | -------------: | ----------------------: |
|    10 |                           1 |             10 |                   $1.62 |
|    10 |                           4 |             40 |                   $6.48 |
|    50 |                           1 |             50 |                   $8.10 |
|    50 |                           2 |            100 |                  $16.20 |
|    50 |                           4 |            200 |                  $32.41 |
|   150 |                           1 |            150 |                  $24.30 |
|   150 |                           3 |            450 |                  $72.91 |
|   150 |                           6 |            900 |                 $145.83 |
|   500 |                           1 |            500 |                  $81.01 |
|   500 |                           2 |          1,000 |                 $162.03 |
| 1,000 |                           1 |          1,000 |                 $162.03 |
| 1,000 |                           4 |          4,000 |                 $648.11 |

> **Interpretation:**
>
> - Each “session” includes four image variants, four descriptions, one summary, and one structured
>   payload.
> - Add ~$0.0004 per session if we send a reference avatar into the prompt (image-to-image seeding).
> - Budget an extra ~$0.0004 for each additional reference image when running editing or multi-image
>   composition flows.
> - Apply adoption rates (for example, 60% of users opt in → multiply totals by 0.6) to reflect real
>   usage.

---

```mermaid
bar
    title Monthly AI Cost by Active User Cohort (TecHub)
    orientation horizontal
    x-axis Monthly Cost (USD)
    y-axis User Cohort
    series Total Cost
        "50 users (4x/month)": 32.41
        "150 users (6x/month)": 145.83
        "500 users (2x/month)": 162.03
        "1,000 users (4x/month)": 648.11
```

---

## Future Optimisations

- Add **provider switching** for typography or realism use cases.
- Experiment with **prompt compression** or **shared templates** to reduce tokens.
- Evaluate **local embeddings** for summaries to reduce API calls.

---

Would you like me to include a **“high-activity burst” forecast** (e.g. product launch week with 10×
usage)? That’s useful for budgeting around campaigns or feature drops.
