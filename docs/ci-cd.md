# CI / CD

This document explains our current CI setup on GitHub Actions and the planned handoff to automated
deploys with Kamal.

## Current CI (GitHub Actions)

Workflows (see `.github/workflows/`):

- CI: runs `bin/ci` which orchestrates Rubocop, Prettier, and the Rails test suite.
- CodeQL: static analysis for security.

Caching:

- Bundler and npm caches are enabled by Actions to speed up runs.

Secrets:

- CI does not require production secrets. It uses test-mode defaults and fixtures.

## Planned CD (Kamal via Actions)

Goal: On merges to `main` with a green CI, build/push the image to GHCR and deploy with Kamal.

High-level workflow:

1. Build and tag image: `ghcr.io/techub-life/techub:<sha>`
2. Push to GHCR using `KAMAL_REGISTRY_PASSWORD` (packages:write scope)
3. SSH to the production host and run `bin/kamal deploy`

Required repository secrets:

- `KAMAL_REGISTRY_PASSWORD` (GHCR token with packages:write)
- `RAILS_MASTER_KEY` (for credentials on server)
- `KAMAL_SSH_KEY` (deploy key to access the VPS), or use a GitHub-hosted SSH action
- `WEB_HOSTS` (optional override if not committed)

Sample job step outline:

```yaml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    needs: [ci]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
      - name: Docker login GHCR
        run:
          echo "${{ secrets.KAMAL_REGISTRY_PASSWORD }}" | docker login ghcr.io -u techub-life
          --password-stdin
      - name: Build image
        run: docker build -t ghcr.io/techub-life/techub:${{ github.sha }} .
      - name: Push image
        run: docker push ghcr.io/techub-life/techub:${{ github.sha }}
      - name: Deploy with Kamal
        env:
          KAMAL_REGISTRY_PASSWORD: ${{ secrets.KAMAL_REGISTRY_PASSWORD }}
          RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
        run: |
          gem install kamal -N
          bin/kamal deploy
```

Notes:

- The example assumes your `kamal.yml` is configured to use `ghcr.io/techub-life/techub` and that
  server SSH is reachable from the runner. If SSH needs provisioning, add a step to write an SSH
  key.
- For rollbacks, add a `kamal rollback` job gated by a manual workflow dispatch.

## Local Development CI

Run the same checks locally:

```bash
bin/ci
```

This ensures parity with GitHub Actions.
