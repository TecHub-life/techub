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
