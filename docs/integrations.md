# Third‑Party Integrations

This document centralizes how we integrate with external services, what is required to use them, and
the system behavior when an integration is absent. The codebase is the source of truth, but this
guide is the operational checklist.

## Platform & Stack Overview

- Domain & DNS: Namecheap (registrar) with Cloudflare for authoritative DNS, TLS, and caching/proxy.
- Compute: DigitalOcean Droplet (VPS) for web and worker roles (Kamal deploy). Still evolving.
- Object Storage: DigitalOcean Spaces with CDN + custom domain for public assets.
- Web Framework: Rails 8, SQLite (Solid Cache/Queue/Cable), Tailwind v4.
- Container Orchestration: Kamal for zero-downtime deploys to the VPS.
- Source of Truth / Auth: GitHub (App + OAuth).
- AI: Google Gemini Flash 2.5 for avatar/image suites where enabled.
- Observability: Axiom (+ OpenTelemetry) for logs/metrics.

Notes:

- Local development favors minimal external dependencies; production prefers managed services.
- When an integration is missing, the app generally degrades gracefully (see each section below).

## DigitalOcean Spaces (Active Storage)

Purpose: Public storage for generated images (cards, OG, banners). In production, Active Storage
uses Spaces; locally it defaults to Disk.

### Requirements

- A Space (e.g., `techub-life`) in your region (e.g., `nyc3`).
- Access keys with write permissions for the Space.
- CDN enabled for the Space (recommended) and a custom CNAME (e.g., `cdn.techub.life`).
- TLS certificate on the custom CDN domain.

### Rails Configuration

- `config/storage.yml` defines the `:do_spaces` service (S3‑compatible).
- Production uses `:do_spaces` by default. Credentials are taken from Rails credentials or env vars.

Recommended credentials (`bin/rails credentials:edit`):

```yaml
app:
  host: https://techub.life

do_spaces:
  # Use the REGION endpoint with path-style (see config/storage.yml)
  endpoint: https://nyc3.digitaloceanspaces.com
  # Custom CDN domain (CNAME to Spaces CDN hostname)
  cdn_endpoint: https://assets.cdn.techub.life
  bucket_name: techub-life
  region: nyc3
  access_key_id: <key>
  secret_access_key: <secret>
```

Environment variable overrides (optional):

- `DO_SPACES_ENDPOINT`, `DO_SPACES_REGION`, `DO_SPACES_BUCKET`, `DO_SPACES_ACCESS_KEY_ID`,
  `DO_SPACES_SECRET_ACCESS_KEY`, `DO_SPACES_CDN_ENDPOINT`.

### App URL Behavior

- Uploads go through Active Storage. The `public_url` for assets is stored on `ProfileAsset`
  records.
- The helper `ProfilesHelper#canonical_profile_asset_url` rewrites third‑party URLs to the
  configured CDN endpoint when `do_spaces.cdn_endpoint` or `DO_SPACES_CDN_ENDPOINT` is present. This
  keeps user‑facing links on a first‑party host and avoids browser lookalike warnings.
- If no CDN endpoint is configured, the raw Spaces URL is used.
- Views use `profile_card_variants(profile)` and `profile_asset_url` to ensure canonicalization and
  cache‑busting.

### DigitalOcean Console: Step‑by‑Step

1. Create the Space and keys

- Create a Space (public) and generate an access key/secret with write access.

2. Enable CDN and custom domain

- Enable CDN on the Space.
- Add a CNAME (e.g., `assets.cdn.techub.life`) pointing to the Space’s CDN hostname, e.g.,
  `techub-life.nyc3.cdn.digitaloceanspaces.com`.
- Attach/issue a TLS certificate for your custom CDN domain in the DigitalOcean UI (or keep DNS-only
  at Cloudflare and let Cloudflare manage TLS if you don’t proxy through DO).

DNS notes:

- Prefer a simple CNAME in your primary DNS (Cloudflare: set to DNS-only/grey cloud during cert
  issuance; you can keep it DNS-only to avoid double-CDN).
- If you delegate a subdomain via NS records (e.g., `cdn.techub.life` →
  ns1/ns2/ns3.digitalocean.com), then the CNAME for `assets.cdn.techub.life` must live inside the
  delegated zone at DigitalOcean DNS. Otherwise, keep everything in primary DNS and do not delegate.

3. Configure CORS

- Origins: add `https://techub.life` and `https://assets.cdn.techub.life`.
- Methods: GET, HEAD.
- Headers: empty.
- Max Age: 86400.

4. Apply credentials

- Add the credentials block above to Rails credentials (preferred) or export env vars.
- Deploy/restart the app.

5. Verify

- DNS:

```bash
dig +short CNAME assets.cdn.techub.life  # should be techub-life.nyc3.cdn.digitaloceanspaces.com.
```

- In production, visit a profile cards tab and click the download icon. Links should resolve to
  `https://assets.cdn.techub.life/...`.
- Optional CLI probes:

```bash
kamal app exec -i web -- bin/rails runner 'b=ActiveStorage::Blob.create_and_upload!(io: StringIO.new("hi"), filename:"probe.txt"); puts b.url'
kamal app exec -i web -- bash -lc 'curl -IfsS $(bin/rails runner "print ActiveStorage::Blob.last.url") | head -n1'
```

### Behavior if Missing

- If the Space or credentials are not configured:
  - Local files under `/public/generated/<login>/` are still used where available.
  - Upload services will skip uploading unless explicitly forced in non‑production.
  - The app continues to render cards with local fallbacks; downloads won’t use CDN.

---

## GitHub (App + OAuth)

Purpose: Fetch user metadata, repos, and drive profile generation.

Requirements:

- GitHub App with App ID, private key, installation ID.
- OAuth Client ID/Secret for user sign‑in.

Configuration:

- Set via Rails credentials `github.*` or env vars (`GITHUB_APP_ID`, `GITHUB_PRIVATE_KEY[_PATH]`,
  `GITHUB_INSTALLATION_ID`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GITHUB_WEBHOOK_SECRET`).

Behavior if Missing:

- Auth features and profile sync will not function. The app can still boot locally for UI smokes.

---

## Resend (Email)

Purpose: Transactional emails (not yet fully enabled).

Requirements:

- `RESEND_API_KEY` when email is enabled.

Behavior if Missing:

- Email features are disabled; the app continues to function.

---

## Observability (Axiom / OTEL)

Purpose: Centralized logs/metrics/traces.

Requirements:

- `axiom.token` in credentials. Non-secret defaults (datasets, org, OTEL endpoint) live in
  `AppConfig.axiom` and can be overridden with `AXIOM_*` env vars if you need something other than
  `otel-logs`/`otel-traces`.

Behavior if Missing:

- Local logs only; core features continue to work.

---

## Backups (S3‑compatible)

Purpose: Periodic SQLite backups to S3/Spaces.

Requirements:

- Backup bucket and keys. Reads from `do_spaces.backup_bucket_name/prefix` or env overrides.

Behavior if Missing:

- Backup jobs will fail fast; application runtime is unaffected.

---

## Quick Reference: What to Set for Production

- GitHub: App ID, installation ID, private key, OAuth client id/secret, webhook secret.
- App Host: `app.host` in credentials or `APP_HOST` env.
- Active Storage: `do_spaces.*` credentials and `cdn_endpoint` for first‑party CDN links.
- Optional: Axiom/OTEL, Resend.

When in doubt, deploy and run the smoke checks in the README’s Production Smoke Checks section.

---

## Cloudflare (DNS, TLS, Proxy)

Purpose: DNS hosting, TLS termination, and optional proxy/caching in front of `techub.life` and
`cdn.techub.life`.

Requirements:

- Domain registered at Namecheap (or similar) with nameservers pointing to Cloudflare.
- DNS records:
  - `A techub.life` → server IP (or CNAME to your load balancer)
  - `CNAME www` → `techub.life`
  - `CNAME cdn` → Spaces CDN hostname (e.g., `techub-life.nyc3.cdn.digitaloceanspaces.com`)
- TLS certificates auto-managed by Cloudflare for apex and subdomains.

Behavior if Missing:

- You can still point DNS directly at the server with your registrar. CDN subdomain will need a cert
  at the provider (DigitalOcean CDN) instead of Cloudflare.

---

## DigitalOcean VPS (Droplet)

Purpose: Host Rails web and worker containers deployed via Kamal.

Requirements:

- A Droplet reachable via SSH. Add an SSH config alias (see README) and ensure you can run Kamal.
- Docker installed; Kamal will manage containers and volumes on the host.

Behavior if Missing:

- You can run locally via Docker Compose or bare `bin/dev` for development. Production requires a
  reachable host for Kamal.

---

## Kamal (Deploys)

Purpose: Containerized deploys with simple configuration.

Requirements:

- GHCR credentials (`KAMAL_REGISTRY_PASSWORD`) to push the image.
- SSH access to the VPS specified by `WEB_HOSTS`/`JOB_HOSTS`.

Behavior if Missing:

- Local development is unaffected; production deploys cannot proceed.

Planned CI/CD:

- We intend to run Kamal from GitHub Actions on successful builds of `main`. The workflow will:
  1. Build and push the image to GHCR
  2. Run `bin/kamal deploy` using repository secrets (RAILS_MASTER_KEY, KAMAL_REGISTRY_PASSWORD, SSH
     key)

---

## GitHub (Source, Actions, App & OAuth)

Purpose: Source hosting, CI, and authentication to the GitHub API (App + OAuth).

Current CI:

- GitHub Actions workflows:
  - CI: runs `bin/ci` (Rubocop, Prettier, test suite)
  - CodeQL: static analysis

Planned CI/CD:

- After CI passes on `main`, a deploy job runs Kamal against the production host, using repository
  secrets for GHCR and SSH.

Behavior if Missing:

- You can run CI locally (`bin/ci`). Authentication to GitHub’s API (App/OAuth) will not work
  without credentials; core UI can still run for local smoke tests.

---

## Gemini Flash 2.5 (AI)

Purpose: Optional AI image/avatar generation where opted-in.

Requirements:

- Google project and credentials (see `docs/observability/axiom-opentelemetry.md` for pattern; add a
  dedicated AI doc if needed).
- For motifs lore generation: ensure `Gemini::Configuration` is set; then use `/ops/motifs` →
  “Generate Missing Lore (Gemini)”.

Behavior if Missing:

- Falls back to real avatars or deterministic in-repo image sets; app remains functional.

---

## Axiom / OpenTelemetry

Purpose: Centralized logs/metrics/traces.

Requirements:

- `axiom.token` in credentials. Override dataset/org/endpoint via env if you need non-default values.

Behavior if Missing:

- Local logs only; core features continue to work.

---

## Frontend Assets: Font Awesome (No CDN)

Purpose: Use Font Awesome icons without third‑party CDNs. Assets are bundled and served locally via
Propshaft.

### How it works (implemented)

- We install `@fortawesome/fontawesome-free` from npm.
- `npm postinstall` copies webfonts into `app/assets/webfonts` and concatenates `all.min.css` into
  `app/assets/stylesheets/application.css`.
- The layout does NOT include a separate FA `<link>`; it only links `tailwind` and `application`.

### Implementation

- Gemfile: no Font Awesome gem required (Rails 8 + Propshaft).
- package.json:
  - `dependencies` includes `"@fortawesome/fontawesome-free"`.
  - `scripts.postinstall` copies webfonts and appends FA CSS to `application.css`.
- Assets paths: default Propshaft paths are sufficient; webfonts live under `app/assets/webfonts`.
- Layout (`app/views/layouts/application.html.erb`):
  - Only: `<%= stylesheet_link_tag "tailwind" %>` and `<%= stylesheet_link_tag "application" %>`.

### Dockerfile considerations

- The base image installs `nodejs` and `npm`.
- Build stage runs `npm install` (triggering `postinstall`) and `./bin/rails assets:precompile`.
- No network calls to third‑party CDNs at runtime for icons.

### Rationale

- Deterministic builds, no external outages, CSP‑friendly, version‑controlled updates.

### Verification

- Grep for CDN links:
  - No `cdnjs`, `jsdelivr`, `unpkg`, or `fontawesome` external links.
- Test/CI: controller view tests pass without asset load errors.
- UI smoke: icons render with classes like `fa-solid`/`fa-brands`.

### Troubleshooting: Stale or Wrong Styles in Development

If the UI looks different between development and production after running a local precompile, you
likely have stale, fingerprinted assets in `public/` shadowing fresh Tailwind output.

Fix:

```bash
# stop the dev server first
rm -rf public/assets public/build tmp/cache
bin/rails assets:clobber

# then either let dev serve sources (recommended) or re-precompile
bin/rails tailwindcss:watch   # for live dev
# or
bin/rails assets:precompile   # when testing production build locally
```

Notes:

- `assets:clobber` removes precompiled outputs (e.g., `public/assets/*`), not your source files.
- After cleaning, hard‑refresh with cache disabled to purge stale browser CSS.
