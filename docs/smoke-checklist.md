# Smoke Checklist (End‑to‑End)

Use this to verify TecHub in dev/staging/prod. Keep it short, real, and current.

## Prereqs

- App running (dev: `bin/dev`; prod: deployed via Kamal)
- Credentials configured (GitHub App/OAuth; DO Spaces if using uploads)
- Optional: Gemini configured for lore generation

## Public UI

1. Home loads

```bash
curl -I http://localhost:3000/
```

Expect: `200 OK`

2. FAQ loads

```bash
curl -I http://localhost:3000/faq
```

Expect: `200 OK`

3. Directory & motifs

```bash
curl -I http://localhost:3000/directory
curl -I http://localhost:3000/archetypes
curl -I http://localhost:3000/spirit-animals
```

Expect: `200 OK` for each

## Auth (GitHub OAuth)

1. Redirect works

```bash
curl -I http://localhost:3000/auth/github
```

Expect: `302 Found` → Location to `https://github.com/login/oauth/authorize?...`

2. Browser sign‑in

- In a browser, visit `/auth/github`, authorize, return to app
- Expect to land on home page with flash “Signed in as @login”

## My Profiles (optional if seeded)

- If you own a profile: `/profiles/:username` loads and JSON endpoint works
  (`/profiles/:username.json`)

## Ops (requires HTTP Basic in prod if configured)

1. Panel reachable

```bash
curl -u user:pass -I http://localhost:3000/ops
```

Expect: `200 OK`

2. Motifs seeding

```bash
curl -u user:pass -X POST http://localhost:3000/ops/motifs/seed_from_catalog
```

Expect: `302 Found` redirect back to `/ops/motifs` with notice

3. Generate missing lore (Gemini)

```bash
curl -u user:pass -X POST http://localhost:3000/ops/motifs/generate_missing_lore
```

Expect: `302 Found` with notice `Lore generation complete (updated N)`

## Assets & OG

- Visit `/cards/:login/og` and `/og/:login.jpg` (for an existing profile)
- Expect images (200). If missing, first hit may queue generation.

## Email (optional)

1. Ops smoke

```bash
curl -u user:pass -X POST http://localhost:3000/ops/send_test_email -d 'to=you@example.com&message=Hello'
```

Expect: `302 Found` with notice

## Account settings

- Sign in → go to `/settings/account`
- Set/clear contact email; save
- Expect: “Account updated”; profile still works when email is blank

## Quick Troubleshooting

- 403 on `/ops`: set/verify HTTP Basic creds (see README/integrations)
- OAuth callback mismatch: fix GitHub OAuth callback URL to
  `http://127.0.0.1:3000/auth/github/callback` (dev)
- Motif thumbs missing: ensure asset-by-slug or upload URL; placeholder is used otherwise
