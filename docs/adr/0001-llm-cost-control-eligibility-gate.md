## ADR 0001: LLM cost control via eligibility gate and profile fallback

Date: 2025-10-10

Status: Accepted

### Context

Image generation and multi‑modal description calls to Gemini are the primary cost drivers in the
avatar pipeline. GitHub profile data is free to fetch and store locally. We need to prevent
low‑signal or empty profiles from consuming paid tokens while preserving a good experience for
eligible users.

### Decision

1. Introduce an eligibility gate before any Gemini calls

- Service: `Eligibility::GithubProfileScoreService`
- Signals: account age, repository activity, social proof, meaningful profile (bio/README/pins),
  recent public events
- Threshold: default 3 signals met (configurable)
- Integration: `Avatars::AvatarImageSuiteService` accepts `require_profile_eligibility` and
  `eligibility_threshold`. When enabled, the service exits early for ineligible profiles with signal
  breakdown in metadata.

2. Robust prompt generation with fallback

- Service: `Avatars::AvatarPromptService`
- Primary: attempt avatar description using Gemini vision
- Fallback: when the LLM result fails or is weak, synthesize a description from stored `Profile`
  context (name, summary, languages, repos, orgs) and proceed to image generation

### Consequences

- Cost protection: paid Gemini calls are avoided for ineligible profiles
- Predictable generation: eligible profiles still succeed even if the LLM flaps, using profile
  fallback
- Clear observability: results include metadata (`fallback_profile_used`, eligibility signals) for
  dashboards or logs

### Operationalization

- CLI: enable the gate via env variables when running generation tasks:

```
REQUIRE_ELIGIBILITY=true bundle exec rake "gemini:avatar_generate[login]"
REQUIRE_ELIGIBILITY=true ELIGIBILITY_THRESHOLD=4 bundle exec rake "gemini:avatar_generate[login]"
```

- Code: pass `require_profile_eligibility: true` and optional `eligibility_threshold:` when calling
  `Avatars::AvatarImageSuiteService`.

### Alternatives considered

- Always call LLMs and cache results: higher cost, still wastes spend on empty profiles
- Hard caps/quotas per user: orthogonal; can be layered later

### Related

- `docs/gemini-setup.md` – usage and flags
- `app/services/gemini/avatar_image_suite_service.rb` – gate implementation
- `app/services/eligibility/github_profile_score_service.rb` – scoring logic
