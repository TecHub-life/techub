# End-to-end testing plan

## Goals

- Verify critical user flows: sync/import, AI generation, card rendering, OG serving, JSON assets
  API
- Run locally using production docker-compose with safe test credentials
- Provide smoke and regression coverage with minimal flake

## Environment

- Use `docker-compose.prod.yml` locally with test env vars
- Secrets are sourced from encrypted credentials when `RAILS_MASTER_KEY` is present
- External services:
  - Gemini: set provider to AI Studio with a test API key, or stub network
  - Storage: disable upload or point to a dev DO Space/S3 bucket

## Strategy

1. Controller/system tests (Rails):

- Stub Gemini HTTP calls with Faraday test adapter where practical
- Drive HTML routes for `/cards/:login/*` and `/og/:login.jpg`
- Validate `/api/v1/profiles/:username/assets` payloads

2. Browser E2E (optional):

- Use Playwright against `docker-compose` stack
- Flows:
  - Create or import a profile
  - Trigger pipeline (without AI cost), verify generated local files and OG route
  - Toggle avatar choice in Settings, verify rendered pages

3. Data fixtures:

- Provide seed profile with realistic `profile_card`, `profile_assets`
- Include sample generated files under `public/generated/<login>/`

## Commands

- Local stack:
  - `docker compose -f docker-compose.prod.yml up -d`
- Test in host dev shell:
  - `bin/rails test`
  - Optional Playwright: `npx playwright test`

## Notes

- Keep live credentials out of test runs; only use test API keys/buckets
- Network calls should be stubbed in CI to ensure determinism
