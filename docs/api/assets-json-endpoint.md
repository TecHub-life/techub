# Assets JSON API

Public, read-only API to consume TecHub profile card assets in external sites (README badges,
portfolios, blogs).

## Endpoint

GET /api/v1/profiles/:username/assets

- Path params:
  - username: GitHub login (case-insensitive)
- Response: 200 OK

```json
{
  "profile": {
    "login": "loftwah",
    "display_name": "Loftwah",
    "updated_at": "2025-10-19T12:34:56Z"
  },
  "card": {
    "title": "Tech builder",
    "tags": ["ruby", "ai"],
    "archetype": "architect",
    "spirit_animal": "falcon",
    "avatar_choice": "ai",
    "avatar_source_id": "upload:avatar_1x1",
    "bg_choices": { "card": "library", "og": "library", "simple": "color" }
  },
  "assets": [
    {
      "kind": "avatar_1x1",
      "public_url": "https://cdn.example.com/loftwah/avatar-1x1.jpg",
      "mime_type": "image/jpeg",
      "width": 1024,
      "height": 1024,
      "provider": "ai_studio",
      "updated_at": "2025-10-19T12:30:00Z"
    }
  ]
}
```

- Errors:
  - 404 { "error": "not_found" }

## Usage examples

- README markdown image:
  - `![TecHub Card](https://techub.life/og/loftwah.jpg)`
- JSON-driven consumers can fetch the array, pick preferred kinds:
  - `og`, `avatar_3x1`, `avatar_16x9`, `avatar_1x1`.

## Notes

- Responses are cache-friendly; assets themselves should be long-lived.
- For HTML OG usage, prefer the image route `/og/:login.jpg` which generates on-demand if missing.
- `avatar_choice` remains for backward compatibility; prefer using `avatar_source_id`.
