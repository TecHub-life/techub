### Gemini setup (zero-BS quick start)

1. Put your API key into encrypted credentials

```yaml
google:
  api_key: YOUR_GEMINI_API_KEY
```

Use `EDITOR="cursor --wait" bin/rails credentials:edit`.

2. Local env for dev

```bash
GEMINI_PROVIDER=ai_studio
```

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

---

### Avatar description & TecHub prompt demo

Once an avatar image is stored locally (e.g., via `Profiles::SyncFromGithub`), you can generate a
Gemini-backed description plus TecHub-flavoured prompts:

```bash
bundle exec rake gemini:avatar_prompt[loftwah]
# supply a custom path or tweak the style profile
bundle exec rake gemini:avatar_prompt AVATAR_PATH=public/avatars/loftwah.png STYLE="Neon-lit anime portrait"
```

> **zsh tip**: wrap the task name in quotes (or escape the brackets) so the shell doesn't treat `[]`
> specially, e.g. `bundle exec rake "gemini:avatar_prompt[loftwah]"`.

The task composes `Gemini::AvatarDescriptionService` and
`Gemini::AvatarPromptService`, printing the avatar description and four ratio-ready prompts
(1×1, 16×9, 3×1, 9×16). Failures include debug metadata so you can inspect Gemini responses quickly.
Prompts simply restate the avatar description plus structured traits, giving image models a grounded brief without extra UI instructions.

To prove the full pipeline (description → prompts → images), run:

```bash
bundle exec rake gemini:avatar_generate[loftwah]
# optional overrides
bundle exec rake gemini:avatar_generate[loftwah, "Neon anime hero energy", public/avatars/loftwah.png, tmp/generated]
```

This drives `Gemini::AvatarImageSuiteService`, generating PNGs for the four aspect ratios via
`Gemini::ImageGenerationService` and writing them to `public/generated/<login>/`. The command prints
paths for easy preview and re-use, and echoes the structured traits alongside the summary so you can
see which features informed each prompt.

> **zsh tip**: quote the whole rake invocation when passing multiple arguments, e.g.
> `bundle exec rake "gemini:avatar_generate[loftwah,Neon anime hero energy]"`.

---

### Quick story demo

Once a profile record exists locally, you can spin up a short narrative that proves text
generation as well:

```bash
bundle exec rake gemini:profile_story[loftwah]
```

The command uses `Profiles::StoryFromProfile` to build a ~120 word micro-story grounded in the
profile's summary, languages, repositories, organisations, and social handles.

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

4. Enable the preview model (Gemini 2.5 Flash Image) and ensure org policy allows it.

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
- Costs/quotas
  - Image output uses ~1290 tokens per 1024×1024 image (see token table on
    [ai.google.dev](https://ai.google.dev/gemini-api/docs/image-generation)). Respect model‑level
    rate limits.
- Fallback logic (already wired)
  - If Vertex image gen fails due to policy/preview, our checks/routes can use the API key path
    instead. You don’t need to change code.
