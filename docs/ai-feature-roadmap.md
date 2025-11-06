# AI Feature Roadmap (Gemini Relaunch)

This roadmap restarts TecHub’s AI surface area with a controlled, measurable rollout that keeps
costs predictable, moderates generated assets, and avoids the prior Vertex AI pitfalls.

---

## Objectives

- Deliver fresh profile imagery (four variants per request) plus accessibility-friendly
  descriptions.
- Provide long-form summaries and structured profile payloads that downstream surfaces can consume.
- Keep operational control in Ops while we validate quality, safety, and cost signals.
- Standardise on **Google AI Studio** (Gemini 2.5 Flash) while keeping Vertex available as an
  explicit fallback when service-account routing or regional policy requires it.

---

## Guiding Principles

- **AI Studio first:** Default to API-key flows; keep Vertex credentials dormant but documented so
  ops can opt in when AI Studio is rate-limited or preview-gated.
- **Feature flagged:** Exposure via user Settings and Ops panel toggles; nothing auto-enables
  without business sign-off.
- **Human-reviewed:** Every generated asset ships with a moderation status. Ops clearance is
  required before anything becomes public.
- **Cost transparency:** Emit per-request metadata (tokens, prompt IDs, feature flag) to
  observability stacks so finance can reconcile against the forecasts in
  `docs/ai-costs-and-usage.md`.

---

## Roadmap

| Phase                        | Scope                                    | Key Workstreams                                                                                                                                                                                                                                                    | Exit Criteria                                                                       |
| ---------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| **0. Platform prep**         | AI Studio default, Vertex fallback ready | • Stand up AI Studio project + service identity<br>• Audit provider ordering/feature flags (`GEMINI_PROVIDER_ORDER`, `:ai_*` flags)<br>• Document Vertex creds storage + approval flow<br>• Update cost dashboards to expect AI Studio billing exports             | AI Studio path green; Vertex path documented and behind manual opt-in               |
| **1. Controlled Ops alpha**  | Ops-triggered generations only           | • Backend job to request 4 profile variants, 4 captions, summary, JSON bundle<br>• Store assets + metadata (references, moderation status)<br>• Ops panel tab to review/approve/deny per asset<br>• CLI/script to enqueue manual requests for seeded users         | Ops can generate & moderate assets end-to-end; costs align with forecast            |
| **2. Opt-in user beta**      | Self-service button in Settings          | • Settings UI: “Request new profile art” + optional avatar upload consent<br>• Capture GitHub avatar (if available) as optional reference image<br>• Queue jobs with throttling + Ops auto-notifications<br>• Email/in-product messaging for completion            | First 50–150 users generate successfully with <5% failure rate; moderation SLA <24h |
| **3. Feature hardening**     | Broader rollout & automation             | • Automate moderation heuristics (NSFW, duplicates, hallucinations)<br>• Introduce regeneration cooldowns and spend guardrails<br>• Expand structured output to feed marketing / community surfaces<br>• Document playbooks for incident response & quality audits | Ready for 500+ monthly generators; support can self-serve common issues             |
| **4. Expansion experiments** | Portfolio add-ons                        | • Test image-to-image seeding vs. describe-then-generate flows<br>• Offer curated style packs or seasonal prompts<br>• Evaluate batching for campaigns/high-activity bursts<br>• Consider additional modalities (audio snippets, short video) once costs validated | Decision on next modality and commercial packaging                                  |

---

## Experiment Tracks

- **Image seeding vs. text-only prompts:** Measure quality uplift when we pass a user-supplied
  avatar (counts as ~1,290 input tokens ≈ $0.0004). Keep both flows available for A/B testing.
- **Image editing & multi-image composition:** Extend ops tooling beyond text-to-image so we can
  selectively unblur, restyle, or blend references using the same moderation workflow.
- **Alternative aspect ratios:** Default to square outputs now; revisit widescreen once model
  support improves.
- **Ops moderation UX:** Prototype an approval queue with bulk actions, comment threads, and
  auto-expiry for stale requests.

---

## Dependencies

- AI Studio API keys stored in secret manager with rotate-on-demand tooling.
- Observability pipeline to Axiom (tokens, prompt IDs, durations, moderation outcomes).
- Feature flag service capable of audience rollouts (10 → 50 → 150 → 500 users).

---

## Open Questions

1. Should we auto-generate captions for user-uploaded images even when we skip full regeneration?
2. Do we need a “launch week” surge plan (10× traffic) that pre-warms cache buckets or uses batch
   APIs?
3. How do we message Ops review outcomes to users (email, in-app, Slack webhook)?

Answering these helps finalise the launch communications and support runbooks.
