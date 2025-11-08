### Gemini setup (zero-BS quick start)

1. Put your API key into encrypted credentials

```yaml
google:
  api_key: YOUR_GEMINI_API_KEY
```

Use `EDITOR="cursor --wait" bin/rails credentials:edit`.

2. Local env for dev  
   _(provider auto-detects: we default to **AI Studio** when an API key is present and fall back to
   **Vertex** only when a project/service account is configured. Override via `GEMINI_PROVIDER` or
   reorder providers with `GEMINI_PROVIDER_ORDER`.)_

3. Verify healthchecks

```bash
curl -s http://localhost:3000/up/gemini          # text route → expect 200
curl -s http://localhost:3000/up/gemini/image    # image route → expect 200
```

Docs:

- Gemini image generation (aka nano-banana):
  [ai.google.dev](https://ai.google.dev/gemini-api/docs/image-generation)
- Gemini 2.5 Flash (Vertex image section):
  [cloud.google.com](https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash#image)
- ADR 0001: LLM cost control via eligibility gate and profile fallback:
  docs/adr/0001-llm-cost-control-eligibility-gate.md

### Provider & feature flag quick reference

- Provider selection lives in `Gemini::Configuration` (`app/services/gemini/configuration.rb:1`):
  API key present → `ai_studio`, otherwise fall back to Vertex with ADC/service account credentials.
- Override order with `GEMINI_PROVIDER_ORDER` or edit
  `config/initializers/gemini_provider_order.rb:4` (defaults to AI Studio only to keep Vertex off
  unless explicitly requested).
- Feature flags gate spend-heavy flows:
  - `:ai_text` → enables `Profiles::SynthesizeAiProfileService`
  - `:ai_images` → enables `Gemini::ImageGenerationService`
  - `:ai_image_descriptions` → enables `Gemini::ImageDescriptionService`
- Per-run overrides in the pipeline use `Profiles::GeneratePipelineService` overrides hash (see
  `app/services/profiles/generate_pipeline_service.rb:91`).

---

### Avatar description & TecHub prompt demo

Once an avatar image is stored locally (e.g., via `Profiles::SyncFromGithub`), you can generate a
Gemini-backed description plus TecHub-flavoured prompts. The `login` defaults to `loftwah` if not
provided (override via arg or `LOGIN=...`):

```bash
bundle exec rake "gemini:avatar_prompt"
# run both providers back-to-back
bundle exec rake "gemini:avatar_prompt:verify[loftwah]"
# force a provider per run
bundle exec rake "gemini:avatar_prompt[loftwah,,,vertex]"
# supply a custom path or tweak the style profile
bundle exec rake gemini:avatar_prompt AVATAR_PATH=public/avatars/loftwah.png STYLE="Neon-lit anime portrait"
# or add PROVIDER=ai_studio/vertex to the env for any task
PROVIDER=ai_studio bundle exec rake "gemini:avatar_prompt[loftwah]"
```

> **zsh tip**: wrap the task name in quotes (or escape the brackets) so the shell doesn't treat `[]`
> specially, e.g. `bundle exec rake "gemini:avatar_prompt[loftwah]"`.

The task composes `Gemini::ImageDescriptionService` and `Avatars::AvatarPromptService`, printing the
avatar description and four ratio-ready prompts (1×1, 16×9, 3×1, 9×16). Failures include debug
metadata so you can inspect Gemini responses quickly. Prompts simply restate the avatar description
plus structured traits, giving image models a grounded brief without extra UI instructions.

To prove the full pipeline (description → prompts → images), run:

```bash
bundle exec rake "gemini:avatar_generate"
# override the provider just for this run
bundle exec rake "gemini:avatar_generate[loftwah,,,public/generated,ai_studio]"
# check both providers and write outputs into public/generated/<login>
bundle exec rake "gemini:avatar_generate:verify"
# optional overrides
bundle exec rake "gemini:avatar_generate[loftwah,Neon anime hero energy,public/avatars/loftwah.png,public/generated]"
```

This drives `Avatars::AvatarImageSuiteService`, generating PNGs for the four aspect ratios via
`Gemini::ImageGenerationService` and writing them to `public/generated/<login>/`. When both
providers are used together (verify task), files are suffixed by provider to avoid overwrites, e.g.
`avatar-1x1-ai_studio.png` and `avatar-1x1-vertex.png`. The command prints paths for easy preview
and re-use, and echoes the structured traits alongside the summary so you can see which features
informed each prompt.

Eligibility gate (optional but recommended):

You can require a minimum-quality profile before spending tokens on generation. This gate uses
`Eligibility::GithubProfileScoreService` (signals: account age, repo activity, social proof,
meaningful profile, recent events). Enable it for the generate tasks via env vars:

```bash
# Require eligibility and use default threshold (3 signals)
REQUIRE_ELIGIBILITY=true bundle exec rake "gemini:avatar_generate[loftwah]"

# Adjust threshold if you want to be stricter/looser
REQUIRE_ELIGIBILITY=true ELIGIBILITY_THRESHOLD=4 bundle exec rake "gemini:avatar_generate[loftwah]"
```

If the profile fails the gate, generation exits early with a clear error and signal breakdown in
metadata. When the gate passes, description is attempted via Gemini; on failure or weak output, the
prompt service synthesizes a description from the stored `Profile` context and proceeds to image
generation.

> **zsh tip**: quote the whole rake invocation when passing multiple arguments, e.g.
> `bundle exec rake "gemini:avatar_generate[loftwah,Neon anime hero energy]"`.

---

### Quick story demo

Once a profile record exists locally, you can spin up a short narrative that proves text generation
as well:

```bash
bundle exec rake "gemini:profile_story"
# choose provider explicitly when testing
bundle exec rake "gemini:profile_story[loftwah,ai_studio]"
# or slam both providers in one go
bundle exec rake "gemini:profile_story:verify"
```

The command uses `Profiles::StoryFromProfile` to build a ~120 word micro-story grounded in the
profile's summary, languages, repositories, organisations, and social handles.

---

### All-in-one verification

Run prompts, images (8 total, 4 per provider), and stories for both providers in one go:

```bash
bundle exec rake "gemini:verify_all[,,,public/generated]"
```

Outputs:

- Avatar prompts printed per provider
- 8 images written to `public/generated/<login>/avatar-<ratio>-<provider>.png`
- Two micro-stories (one per provider) printed to the console

---

### Nano Banana modes (REST proof points)

We keep lightweight scripts in the ops toolkit, but you can prove each Gemini image mode via `curl`
before wiring new flows. These snippets mirror the official docs so we spot regressions quickly.

#### Text-to-image

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [
        {"text": "Create a picture of a nano banana dish in a Gemini-themed restaurant"}
      ]
    }]
  }' \
  | grep -o '"data": "[^"]*"' \
  | head -n 1 \
  | cut -d'"' -f4 \
  | base64 --decode > /tmp/nano-banana.png
open /tmp/nano-banana.png  # macOS helper; swap for xdg-open/display as needed
```

#### Image + text editing

```bash
IMG_PATH="public/avatars/loftwah.png"
if [[ "$(base64 --version 2>&1)" = *"FreeBSD"* ]]; then B64FLAGS="--input"; else B64FLAGS="-w0"; fi

curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "'"$(base64 $B64FLAGS "$IMG_PATH")"'"
          }
        },
        {
          "text": "Remix this portrait as a neon-lit hero card with cyberpunk lighting."
        }
      ]
    }]
  }' \
  | grep -o '"data": "[^"]*"' \
  | head -n 1 \
  | cut -d'"' -f4 \
  | base64 --decode > /tmp/nano-banana-edit.png
```

#### Multi-image composition / style transfer

```bash
STYLE_REF="public/reference/style.png"
CONTENT_REF="public/reference/pose.png"
if [[ "$(base64 --version 2>&1)" = *"FreeBSD"* ]]; then B64FLAGS="--input"; else B64FLAGS="-w0"; fi

curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "'"$(base64 $B64FLAGS "$STYLE_REF")"'"
          }
        },
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "'"$(base64 $B64FLAGS "$CONTENT_REF")"'"
          }
        },
        {
          "text": "Blend the pose from the second image with the illustrated style from the first."
        }
      ]
    }]
  }' \
  | grep -o '"data": "[^"]*"' \
  | head -n 1 \
  | cut -d'"' -f4 \
  | base64 --decode > /tmp/nano-banana-style.png
```

- Add these flows to ops jobs once we wrap them in services. `Gemini::ImageGenerationService`
  currently handles text-to-image; we will extend it (or add siblings) for editing and multi-image
  once the pipelines are baked.
- Track outputs via `public/generated/<login>/meta/*.json` to keep provenance.

---

### Artifacts and VERBOSE mode

When generating images via the suite, the exact inputs are persisted for audit and comparison:

- Path: `public/generated/<login>/meta/`
  - `prompts-<provider>.json` — includes `avatar_description`, `structured_description`, and
    `prompts` per variant.
  - `meta-<provider>.json` — includes service metadata such as `provider`, `finish_reason`,
    `attempts`, `theme`, and `style_profile`.

For side-by-side debugging without re-running calls, enable verbose output in verify tasks:

```bash
VERBOSE=1 bundle exec rake "gemini:avatar_prompt:verify[loftwah]"
VERBOSE=1 bundle exec rake "gemini:avatar_generate:verify[loftwah]"
VERBOSE=1 bundle exec rake "gemini:profile_story:verify[loftwah]"
```

Verbose mode prints the provider, theme, style profile, and the exact prompts used (plus rich
metadata for stories).

---

### Image publishing (production) and local dev

- Development/CI: image files are written to `public/generated/<login>/` only.
- Production: when Active Storage is configured for DigitalOcean Spaces (see `config/storage.yml`
  and `config/environments/production.rb`), generated images are uploaded after local write and a
  `public_url` is included in results.
- To exercise real uploads outside production, set `ACTIVE_STORAGE_SERVICE=do_spaces` so the
  pipeline uses the DO Spaces backend.

Rake output shows remote URLs when available:

```bash
VERBOSE=1 bundle exec rake "gemini:avatar_generate:verify"
# ...
- 1x1 (image/png) -> public/generated/loftwah/avatar-1x1.png [url: https://cdn.example/...]
```

Artifacts JSON remain on disk under `public/generated/<login>/meta/`.

---

### Image understanding (describe existing art)

`Gemini::ImageDescriptionService` (`app/services/gemini/image_description_service.rb`) wraps this
flow with retries and structured JSON, but you can smoke test the raw API first:

```bash
IMG_PATH="public/avatars/loftwah.png"
if [[ "$(base64 --version 2>&1)" = *"FreeBSD"* ]]; then B64FLAGS="--input"; else B64FLAGS="-w0"; fi

curl -s \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "'"$(base64 $B64FLAGS "$IMG_PATH")"'"
          }
        },
        {
          "text": "Describe this avatar in 2-3 grounded sentences plus palette and mood."
        }
      ]
    }]
  }' | python -m json.tool | head
```

Enable the `ai_image_descriptions` flag before relying on the service so the pipeline can spend
tokens safely.

---

### Structured output JSON proof

`Gemini::StructuredOutputService` (`app/services/gemini/structured_output_service.rb`) already
handles schema wiring. Use this `curl` to validate the schema TecHub battles need:

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [
        { "text": "Return a balanced TecHub battle profile for loftwah. JSON only." }
      ]
    }],
    "generationConfig": {
      "temperature": 0.25,
      "response_mime_type": "application/json",
      "response_schema": {
        "type": "object",
        "properties": {
          "title": {"type": "string"},
          "attack": {"type": "integer"},
          "defense": {"type": "integer"},
          "speed": {"type": "integer"},
          "tags": {"type": "array", "items": {"type": "string"}}
        },
        "required": ["title", "attack", "defense", "speed", "tags"]
      }
    }
  }' | python -m json.tool
```

Keep this in sync with the schema inside `Profiles::SynthesizeAiProfileService` so we do not break
the JSON contract that TecHub Battles consumes.

---

### URL context tool (selective retrieval)

Useful for grounding bios or comparing external docs. The response includes `url_context_metadata`
so ops can confirm exactly which pages were fetched.

```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [{
        "text": "Compare the ingredients and cooking times from the recipes at https://www.foodnetwork.com/recipes/ina-garten/perfect-roast-chicken-recipe-1940592 and https://www.allrecipes.com/recipe/21151/simple-whole-roast-chicken/."
      }]
    }],
    "tools": [
      { "url_context": {} }
    ]
  }' | python -m json.tool | head
```

Combine with `{ "google_search": {} }` in the tools array when you need discovery before URL
expansion.

---

### Optional: Vertex setup (only if you need Vertex)

1. Encrypted credentials (service account JSON)

```yaml
google:
  project_id: your-project
  location: us-central1
  application_credentials_json: |
    { "type": "service_account", ... }
```

2. Local env

```bash
GEMINI_PROVIDER=vertex
GOOGLE_CLOUD_PROJECT=your-project
GEMINI_LOCATION=us-central1
```

3. Required roles (on the service account)

- Vertex AI User (roles/aiplatform.user)
- Service Usage Consumer (roles/serviceusage.serviceUsageConsumer)

4. Image generation on Vertex
   - Gemini 2.5 Flash includes an image generation section. Some orgs/projects require enabling the
     preview image model and allowing it via org policy. If blocked (400/404), run with AI Studio
     until Vertex is enabled.

5. Verify

```bash
curl -s http://localhost:3000/up/gemini/image  # expect 200 once enabled
```

---

### Known limits and gotchas (read this once)

- Endpoints we use programmatically
  - API key path: `POST /v1beta/models/gemini-2.5-flash:generateContent` (text/JSON/vision) and
    `POST /v1beta/models/gemini-2.5-flash-image:generateContent` (image gen) — see
    [ai.google.dev](https://ai.google.dev/gemini-api/docs/image-generation)
  - Vertex path:
    `POST /v1/projects/{project}/locations/{location}/publishers/google/models/{model}:generateContent`
    — image section for Gemini 2.5 Flash is documented at
    [cloud.google.com](https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash#image)
- Regions
  - Gemini 2.5 Flash (image section) lists availability in `us-central1` (check doc above). If a
    region 404s, switch to `us-central1`.
- Preview gating
  - Vertex image gen (“Flash Image”/nano‑banana) may require enabling the preview model and org
    policy allowlists. If blocked (400/404), use the API key path which works immediately once your
    key is active.
- Payload shapes (common cases)
  - Text/JSON: `contents: [{role:"user", parts:[{text:"..."}]}]` with optional
    `response_mime_type/application/json` or schema (structured output).
  - Vision (describe): add `{inline_data:{mime_type:"image/png", data: base64}}` to parts.
  - Image gen: prompt only; image bytes are returned in
    `candidates[0].content.parts[].inlineData.data` (base64) per
    [ai.google.dev](https://ai.google.dev/gemini-api/docs/image-generation).
  - Aspect ratio: the API does not currently accept an explicit ratio in our payload; we encode
    composition and desired ratio in the prompt. Expect minor variance in output sizing across
    providers/models.
- Costs/quotas
  - Image output uses ~1290 tokens per 1024×1024 image (see token table on
    [ai.google.dev](https://ai.google.dev/gemini-api/docs/image-generation)). Respect model‑level
    rate limits.
- Fallback logic (already wired)
  - If Vertex image gen fails due to policy/preview, our checks/routes can use the API key path
    instead. You don’t need to change code.

---

### Using generated images in docs

Once images are generated into `public/generated/<login>/`, you can reference them in Markdown. For
example, to include both providers side-by-side for `loftwah`:

```md
![1x1 AI Studio](../public/generated/loftwah/avatar-1x1-ai_studio.png)
![1x1 Vertex](../public/generated/loftwah/avatar-1x1-vertex.png)
```

Tip:

- Commit the files under `public/generated/<login>/` if you want them to render on GitHub.
- Use provider-suffixed filenames to make comparisons explicit in your docs.
