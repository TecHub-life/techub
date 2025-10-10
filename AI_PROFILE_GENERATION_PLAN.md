### AI Profile Generation Plan (Gemini 2.5 Flash — model-locked)

#### 0) Canonical references (must follow)

- Structured output:
  [https://ai.google.dev/gemini-api/docs/structured-output](https://ai.google.dev/gemini-api/docs/structured-output)
- Image understanding (vision):
  [https://ai.google.dev/gemini-api/docs/image-understanding](https://ai.google.dev/gemini-api/docs/image-understanding)
- Text generation:
  [https://ai.google.dev/gemini-api/docs/text-generation](https://ai.google.dev/gemini-api/docs/text-generation)
- Image generation:
  [https://ai.google.dev/gemini-api/docs/image-generation](https://ai.google.dev/gemini-api/docs/image-generation)

#### 1) Scope and outcomes

- Goal: Generate consistent, high‑quality AI-backed profiles and images for GitHub users. Store all
  text and images in our infra (do not hotlink GitHub assets).
- Model lock: All AI generation calls MUST use `gemini-2.5-flash`. Do not deviate or substitute
  models in any environment (dev, staging, prod).
- Outputs:
  - Text: `short_bio`, `long_bio`, `buff`, `buff_description`, `weakness`, `weakness_description`,
    `vibe`, `vibe_description`, `special_move`, `special_move_description`, `flavor_text`, `tags`
    (exactly 6), `avatar_description`.
  - Game stats and traits: `attack` (int 60–99), `defense` (int 60–99), `speed` (int 60–99),
    `playing_card` (e.g., "Ace of ♣"), `spirit_animal` (from allowlist), `archetype` (from
    allowlist).
  - Images: 1:1, 16:9, 3:1 (if we can), 9:16; plus an OpenGraph image for link previews.
  - Structured metadata: `summary`, `languages`, `social_accounts`, `organizations`,
    `top_repositories`, `pinned_repositories`, `active_repositories`, `recent_activity`, and
    `readme.content`.

#### 2) Inputs (exactly as provided and required)

```yaml
What info we want to use for our AI profile generation

profile:
  login: (this is their GitHub handle)
  name: (this is their actual name)
  bio: (this could give us info about them)
  location: (this could be used as part of our generation, we should grab this and store it somewhere)
  blog: (if this exists we want to crawl and grab info from it)
  twitter_username: (we want any social media usernames)
  avatar_url: (we want to generate images using this and profile info)
  public_repos:
  public_gists:
  followers:
  following:

summary: (this is good, we should use this)
languages: (this is good, and tells us what languages someone is working with)
social_accounts: (this is good and we should use this)
organizations: (we can use this to check if the recent activity is actually something they work on and as part of their profile. we don't want to say they work their, but we can say they are part of the organization)
top_repositories: (this is great for the profile, we can learn a lot about what they do here)
pinned_repositories: (this is great for the profile, we can learn a lot about what they are proud of here)
active_repositories: (this is great, but we have to ensure we only talk about repositories that match their handle and organizations they are in)
recent_activity: (this is great, but we have to ensure we only talk about repositories that match their handle and organizations they are in)

readme:
  content: (this is great for telling us about the user and generating our profile)

# Optional inputs to control stats/traits generation and account-level overrides
overrides: (apply these exact values if provided; they take precedence over AI/random)
  attack: (int 60-99)
  defense: (int 60-99)
  speed: (int 60-99)
  playing_card: "Ace of ♣"
  spirit_animal: "Wedge-tailed Eagle"
  archetype: "The Hero"

# Optional allowlists to constrain model choice (if omitted, sensible defaults apply)
allowed_spirit_animals: ["Wedge-tailed Eagle", "Red Fox", "Dolphin", "Orca", "Barn Owl"]
allowed_archetypes: ["The Hero", "The Sage", "The Explorer", "The Creator"]
# If provided, cards must be one of these 52 values, formatted as "<Rank> of <SuitSymbol>"
allowed_playing_cards: ["Ace of ♣", "2 of ♣", "3 of ♣", "4 of ♣", "5 of ♣", "6 of ♣", "7 of ♣", "8 of ♣", "9 of ♣", "10 of ♣", "Jack of ♣", "Queen of ♣", "King of ♣",
  "Ace of ♦", "2 of ♦", "3 of ♦", "4 of ♦", "5 of ♦", "6 of ♦", "7 of ♦", "8 of ♦", "9 of ♦", "10 of ♦", "Jack of ♦", "Queen of ♦", "King of ♦",
  "Ace of ♥", "2 of ♥", "3 of ♥", "4 of ♥", "5 of ♥", "6 of ♥", "7 of ♥", "8 of ♥", "9 of ♥", "10 of ♥", "Jack of ♥", "Queen of ♥", "King of ♥",
  "Ace of ♠", "2 of ♠", "3 of ♠", "4 of ♠", "5 of ♠", "6 of ♠", "7 of ♠", "8 of ♠", "9 of ♠", "10 of ♠", "Jack of ♠", "Queen of ♠", "King of ♠"]
```

- Additional notes to enforce:
  - Keep a copy of the avatar and serve it ourselves (do not serve directly from GitHub).
  - All generated profiles must stay within defined length ranges (min/max characters) for
    consistency.
  - Ask the model to describe the user’s avatar to get a reusable text description.

#### 1.1) Account eligibility gate (free access guardrail)

- Card submissions are now free; we depend on an eligibility check to keep the directory signal-rich
  and to block obvious spam/bot accounts before any AI spend.
- Compute an `eligibility_score` (0–5) for every GitHub account before generation:
  - +1 if the account age is ≥60 days (`profile.created_at`).
  - +1 if there are ≥3 public, non-archived repositories with pushes inside the past 12 months.
  - +1 if followers ≥3 OR following ≥3 (social proof).
  - +1 if the profile has meaningful context: non-empty bio, README content, or ≥1 pinned repo.
  - +1 if `recent_activity` includes ≥5 public events in the past 90 days.
- Accept the submission when `eligibility_score ≥ 3`. Otherwise:
  - Persist a declined state with the failing signals.
  - Return actionable copy (“Grow your GitHub footprint and try again”) so builders know how to get
    approved.
- Maintain allow/block overrides for edge cases (e.g., well-known maintainers with private work).

#### 2.1) Blog crawling (if `profile.blog` exists)

- Respect the blog URL if provided; fetch the homepage and obvious in-domain content sources (for
  example, a sitemap or primary navigation links).
- Extract readable text (titles, headings, paragraphs) and discard boilerplate.
- Produce a compact `blog_digest` (summary and salient topics/claims) for model context.
- Deduplicate by canonical URL; keep it shallow (no detailed crawl parameters specified at this
  planning stage).
- Store the digest for reuse; do not hotlink any media.

#### 3) What we want to generate (text fields)

- short_bio: make them sound awesome in third person, grounded in data.
- long_bio: longer narrative, still grounded.
- buff: game-style buff (≤3 words; e.g., "Deployment Maestro").
- buff_description: "Transforms complex infrastructure into scalable, cost-efficient systems,
  optimizing deployments with precision and expertise."
- weakness: game-style weakness (≤3 words; e.g., "Project Juggler").
- weakness_description: "With countless innovative projects on the go, focus can sometimes scatter,
  leading to a sprawling digital empire."
- vibe: game-style vibe (≤3 words; e.g., "Vibe Coder").
- vibe_description: "Approaches complex technical challenges with an intuitive, creative flow,
  crafting elegant solutions with a unique style."
- special_move: (≤4 words; e.g., "Cloud Optimization Strike").
- special_move_description: "Unleashes advanced AWS strategies to slash infrastructure costs, saving
  massive resources while enhancing performance."
- flavor_text: cool tagline (e.g., "Architecting tomorrow's cloud, today.")
- tags: exactly six tags that match their profile.

#### 3.1) What we want to generate (game stats and traits)

- attack: integer 60–99. Higher → more aggressive coding style or impact potential.
- defense: integer 60–99. Higher → stability, testing rigor, reliability.
- speed: integer 60–99. Higher → delivery pace, responsiveness, shipping velocity.
- playing_card: exactly one from a standard 52-card deck, formatted "<Rank> of <SuitSymbol>" where
  Rank ∈ {Ace, 2..10, Jack, Queen, King} and SuitSymbol ∈ {♣, ♦, ♥, ♠}.
- spirit_animal: single Title Case string chosen from an allowlist when provided.
- archetype: single Title Case string chosen from an allowlist when provided.

#### 4) Images we want to generate

- 1x1 image
- 16x9 image
- 3x1 image (if we can)
- 9x16 image

These images must be usable in the card we generate. Ensure our database can store these assets.

#### 5) Ownership and inclusion rules

- Include repos and activity only if `repo.owner.login == profile.login` OR the owner is in
  `organizations`.
- Do not say the user "works at" an organization; you may state they are part of the organization.
- Ground all statements in provided public data; avoid unverifiable claims.

#### 6) Length and style constraints

- short_bio: 180–220 chars, third person, energetic, no emojis.
- long_bio: 600–900 chars, third person, concrete accomplishments, no fluff.
- buff / weakness / vibe: ≤3 words, Title Case.
- special_move: ≤4 words, Title Case.
- buff_description / weakness_description / vibe_description / special_move_description: 120–180
  chars each.
- flavor_text: ≤80 chars.
- tags: exactly 6, lowercase kebab-case, 1–3 words each, unique.

Stats and traits constraints:

- attack / defense / speed: integers in [60, 99].
- playing_card: must match pattern "^(Ace|[2-9]|10|Jack|Queen|King) of [♣♦♥♠]$".
- spirit_animal: Title Case; must be in `allowed_spirit_animals` if provided.
- archetype: Title Case; must be in `allowed_archetypes` if provided.

#### 7) Storage

- Development: local filesystem.
- Production: DigitalOcean Spaces (already integrated). We do not hotlink GitHub assets.
- Suggested object keys:
  - `users/{login}/avatar/original.{ext}`
  - `users/{login}/images/{variant}.{ext}` (variants: 1x1, 16x9, 3x1, 9x16)
  - `users/{login}/og/{hash}.png`
- Suggested target sizes:
  - 1:1 → 1024×1024
  - 16:9 → 1920×1080
  - 3:1 → 1800×600
  - 9:16 → 1080×1920
  - OpenGraph → 1200×630

#### 8) Minimal database model (to store everything we need)

- `users`(id, github_login, name, location, blog, twitter_username, created_at, updated_at)
- `ai_profiles`(id, user_id, short_bio, long_bio, buff, buff_description, weakness,
  weakness_description, vibe, vibe_description, special_move, special_move_description, flavor_text,
  tags JSONB[6], avatar_description, summary, languages JSONB, blog_digest JSONB, attack SMALLINT,
  defense SMALLINT, speed SMALLINT, playing_card VARCHAR, spirit_animal VARCHAR, archetype VARCHAR,
  model_name, prompt_version, created_at, updated_at)
- `social_accounts`(id, user_id, platform, handle, url)
- `organizations`(id, user_id, org_login, org_name, org_url)
- `repositories`(id, user_id, repo_full_name, owner_login, is_pinned, is_top, is_active,
  description, topics JSONB, languages JSONB, stars, forks, last_activity_at)
- `activities`(id, user_id, type, repo_full_name, timestamp, metadata JSONB)
- `assets`(id, user_id, kind
  enum['avatar_original','image_1x1','image_16x9','image_3x1','image_9x16','og'], storage_key,
  width, height, content_hash, created_at)

Optional overrides table (for account-level locks and auditing):

- `ai_profile_overrides`(id, user_id, attack SMALLINT NULL, defense SMALLINT NULL, speed SMALLINT
  NULL, playing_card VARCHAR NULL, spirit_animal VARCHAR NULL, archetype VARCHAR NULL, created_at,
  updated_at)

#### 9) Model and structured output (Gemini 2.5 Flash)

- Model: `gemini-2.5-flash` (MANDATORY; no fallbacks or alternatives permitted).
- We use structured output with strict JSON. Two supported patterns:
  - `responseMimeType: "application/json"` with a `responseSchema` (Type/Object form).
  - `response_mime_type: "application/json"` with `response_json_schema` (JSON Schema, 2.5-only
    preview). See docs:
    [Structured output](https://ai.google.dev/gemini-api/docs/structured-output).
- Property ordering: set `propertyOrdering` to stabilize output ordering (recommended by docs).

Output schema (Type/Object form) for profile synthesis response:

```json
{
  "type": "OBJECT",
  "properties": {
    "short_bio": { "type": "STRING" },
    "long_bio": { "type": "STRING" },
    "buff": { "type": "STRING" },
    "buff_description": { "type": "STRING" },
    "weakness": { "type": "STRING" },
    "weakness_description": { "type": "STRING" },
    "vibe": { "type": "STRING" },
    "vibe_description": { "type": "STRING" },
    "special_move": { "type": "STRING" },
    "special_move_description": { "type": "STRING" },
    "flavor_text": { "type": "STRING" },
    "tags": { "type": "ARRAY", "items": { "type": "STRING" } },
    "attack": { "type": "INTEGER", "description": "60-99" },
    "defense": { "type": "INTEGER", "description": "60-99" },
    "speed": { "type": "INTEGER", "description": "60-99" },
    "playing_card": { "type": "STRING", "description": "<Rank> of <SuitSymbol>" },
    "spirit_animal": { "type": "STRING" },
    "archetype": { "type": "STRING" }
  },
  "required": [
    "short_bio",
    "long_bio",
    "buff",
    "buff_description",
    "weakness",
    "weakness_description",
    "vibe",
    "vibe_description",
    "special_move",
    "special_move_description",
    "flavor_text",
    "tags",
    "attack",
    "defense",
    "speed",
    "playing_card",
    "spirit_animal",
    "archetype"
  ],
  "propertyOrdering": [
    "short_bio",
    "long_bio",
    "buff",
    "buff_description",
    "weakness",
    "weakness_description",
    "vibe",
    "vibe_description",
    "special_move",
    "special_move_description",
    "flavor_text",
    "tags",
    "attack",
    "defense",
    "speed",
    "playing_card",
    "spirit_animal",
    "archetype"
  ]
}
```

Length and pattern checks will be validated by our app after generation and, if needed, we will
re-ask the model with stricter instructions.

#### 10) Prompting strategy (Gemini 2.5 Flash)

- General rules:
  - Third-person voice; no emojis; ground claims; apply ownership filter.
  - JSON-only replies for structured calls; no text outside JSON.
  - Include `avatar_description` and `blog_digest` in context once available.

Avatar description (vision) request (returns a single string) — see Image understanding:

```json
{
  "model": "gemini-2.5-flash",
  "systemInstruction": {
    "role": "system",
    "parts": [
      {
        "text": "Produce a concise, neutral description of the avatar. Avoid inferring age, identity, or sensitive attributes. Describe clothing, colors, style, background, and overall vibe. 60–90 words. No emojis."
      }
    ]
  },
  "contents": [
    {
      "role": "user",
      "parts": [
        { "inline_data": { "mime_type": "image/png", "data": "<bytes-or-url-ref>" } },
        { "text": "Describe the avatar as specified. Do not infer beyond visible elements." }
      ]
    }
  ],
  "generationConfig": { "temperature": 0.2, "maxOutputTokens": 256 },
  "responseMimeType": "text/plain"
}
```

Profile synthesis (single-call structured JSON) — see Structured output and Text generation:

```json
{
  "model": "gemini-2.5-flash",
  "systemInstruction": {
    "role": "system",
    "parts": [
      {
        "text": "You create engaging, third-person developer profiles grounded in provided public data. Follow the constraints exactly. Only include repositories owned by the user or organizations they belong to. Do not claim employment. Apply any provided overrides exactly as given. Choose attack/defense/speed as integers in 60–99. Pick playing_card from the standard 52-card deck formatted '<Rank> of <SuitSymbol>' using suits ♣ ♦ ♥ ♠. When allowlists are provided for spirit_animal/archetype, pick from those; otherwise choose reasonable, non-controversial options. Output valid JSON matching the provided schema. Reply with JSON only."
      }
    ]
  },
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "{ \n  \"profile\": { \"login\": \"...\", \"name\": \"...\", \"bio\": \"...\", \"location\": \"...\", \"blog\": \"...\", \"twitter_username\": \"...\", \"avatar_url\": \"...\", \"public_repos\": 42, \"public_gists\": 3, \"followers\": 120, \"following\": 88 },\n  \"summary\": \"...\",\n  \"languages\": [{\"name\":\"TypeScript\",\"ratio\":0.52},{\"name\":\"Go\",\"ratio\":0.21}],\n  \"social_accounts\": [{\"platform\":\"twitter\",\"handle\":\"...\",\"url\":\"...\"}],\n  \"organizations\": [{\"login\":\"acme\",\"name\":\"Acme Org\"}],\n  \"top_repositories\": [...],\n  \"pinned_repositories\": [...],\n  \"active_repositories\": [...],\n  \"recent_activity\": [...],\n  \"readme\": { \"content\": \"...\" },\n  \"avatar_description\": \"...\",\n  \"blog_digest\": { \"summary\": \"...\", \"topics\": [\"...\"] },\n  \"overrides\": { \"playing_card\": \"Ace of ♣\" },\n  \"allowed_spirit_animals\": [\"Wedge-tailed Eagle\", \"Red Fox\"],\n  \"allowed_archetypes\": [\"The Hero\", \"The Explorer\"]\n}"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.7,
    "topP": 0.9,
    "maxOutputTokens": 2048,
    "responseMimeType": "application/json",
    "responseSchema": {
      "type": "OBJECT",
      "properties": {
        "short_bio": { "type": "STRING" },
        "long_bio": { "type": "STRING" },
        "buff": { "type": "STRING" },
        "buff_description": { "type": "STRING" },
        "weakness": { "type": "STRING" },
        "weakness_description": { "type": "STRING" },
        "vibe": { "type": "STRING" },
        "vibe_description": { "type": "STRING" },
        "special_move": { "type": "STRING" },
        "special_move_description": { "type": "STRING" },
        "flavor_text": { "type": "STRING" },
        "tags": { "type": "ARRAY", "items": { "type": "STRING" } }
      },
      "required": [
        "short_bio",
        "long_bio",
        "buff",
        "buff_description",
        "weakness",
        "weakness_description",
        "vibe",
        "vibe_description",
        "special_move",
        "special_move_description",
        "flavor_text",
        "tags"
      ],
      "propertyOrdering": [
        "short_bio",
        "long_bio",
        "buff",
        "buff_description",
        "weakness",
        "weakness_description",
        "vibe",
        "vibe_description",
        "special_move",
        "special_move_description",
        "flavor_text",
        "tags"
      ]
    }
  }
}
```

Note: Alternatively, for Gemini 2.5 you can supply `response_json_schema` (preview) with a full JSON
Schema; follow the constraints and limitations described in the official docs.

#### 11) Image generation — see Image generation:

- Use Gemini 2.5 Flash with the stored avatar as visual input to produce: 1x1, 16x9, 3x1 (if
  possible), 9x16.
- Keep facial identity intact; background stylization allowed later (not in scope now). Images must
  be usable in our card UI.
- If image synthesis is unavailable in runtime, request a structured design brief and render
  programmatically. Separate fallback resources will be created for any missing image.

#### 12) OpenGraph image generation

- Use Playwright or Puppeteer to render a dedicated route/view at fixed 1200×630, then screenshot.
- Inputs: name, short_bio, tags, stored avatar URL.
- Store to DO Spaces under `users/{login}/og/{hash}.png`.

#### 13) Processing pipeline (high level)

1. Fetch GitHub profile; download and store avatar; persist base profile fields.
2. Fetch organizations, pinned/top repos, and recent activity; apply ownership filter.
3. Compute languages from repo language bytes (normalize to ratios).
4. Fetch README; if blog exists, crawl and summarize to a compact digest for context (planning only
   at this stage).
5. Generate `avatar_description` (vision) with `gemini-2.5-flash`.
6. Generate all text fields and game stats/traits via a single structured-output call with
   `gemini-2.5-flash` (applying overrides when provided).
7. Generate images (1:1, 16:9, 3:1 if we can, 9:16) with `gemini-2.5-flash`.
8. Generate OG image via Playwright/Puppeteer route.
9. Upload assets to DO Spaces; create `assets` records with dimensions and hashes.
10. Store `ai_profiles` with `model_name=gemini-2.5-flash` and `prompt_version`.

#### 14) Non-requirements and directives (as specified)

- Brand palette and fonts for OG: not needed in this planning document.
- Fallback behavior: you will create default fallback resources for any image we might use.
- Stylization choices: not our concern yet.
- Max crawl pages per domain: not needed at this stage.
- Storage: DigitalOcean Spaces for production (already integrated), local storage for development.

#### 15) Validation and safeguards

- Enforce length bounds and kebab-case tags post-generation; if out of bounds, re-ask with tighter
  instructions.
- Mention only repos/activity that pass ownership filter.
- Third-person voice; no emojis; avoid unverifiable claims.

Additional validation for stats/traits and overrides:

- attack / defense / speed: must be integers in [60, 99]; if out of range, re-ask.
- playing_card: must be one of the 52 valid cards and match the format.
- spirit_animal / archetype: must be in allowlists when provided; otherwise accept as Title Case
  strings from our curated sets.
- Overrides precedence: if `overrides` provides any of these fields, we store and display exactly
  the override value and do not let the model or randomization change it.

#### 16) References (keep these URLs)

- Structured output (Gemini 2.5):
  [https://ai.google.dev/gemini-api/docs/structured-output](https://ai.google.dev/gemini-api/docs/structured-output)
- Image understanding:
  [https://ai.google.dev/gemini-api/docs/image-understanding](https://ai.google.dev/gemini-api/docs/image-understanding)
- Text generation:
  [https://ai.google.dev/gemini-api/docs/text-generation](https://ai.google.dev/gemini-api/docs/text-generation)
- Image generation:
  [https://ai.google.dev/gemini-api/docs/image-generation](https://ai.google.dev/gemini-api/docs/image-generation)

#### 17) Prompt payload: exactly what we send and how we prompt

- Avatar description (vision) — inputs sent:
  - `avatar_image` (binary or URL reference to our stored copy)
  - Optional context: `profile.name`, `profile.bio`
  - Instruction text: request a neutral 60–90 word description; no sensitive attribute inference
- Profile synthesis — inputs sent (single JSON block in user message):
  - `profile`: `login`, `name`, `bio`, `location`, `blog`, `twitter_username`, `avatar_url`,
    `public_repos`, `public_gists`, `followers`, `following`
  - `summary`: short overview we computed
  - `languages`: array of `{ name, ratio }`
  - `social_accounts`: array of `{ platform, handle, url }`
  - `organizations`: array of `{ login, name }`
  - `top_repositories`: filtered list; minimally include `repo_full_name`, `owner_login`,
    `description`, `topics[]`, `languages` (bytes or names/ratios), `stars`, `forks`,
    `last_activity_at`
  - `pinned_repositories`: same shape as above
  - `active_repositories`: same shape as above (post ownership filter)
  - `recent_activity`: recent events aligned to ownership/org membership
  - `readme`: `{ content }`
  - `avatar_description`: string from the avatar vision pass
  - `blog_digest`: `{ summary, topics[] }` if available

- Recommended prompt structure (Gemini 2.5 Flash):
  - System: role and guardrails (third-person, no emojis, ownership filter, JSON-only, respect
    lengths)
  - User: one `parts.text` containing the full JSON context payload (above)
  - Generation config:
    - For structured output: `responseMimeType: application/json`
    - Schema: prefer `responseSchema` (Type/Object form) with `propertyOrdering`; or
      `response_json_schema` (2.5-only preview) when full JSON Schema is needed
    - Decoding: creative (temperature 0.7, topP 0.9) vs factual (temperature 0.2)
  - Ordering and determinism: set `propertyOrdering` and keep example property order consistent with
    schema, per docs
