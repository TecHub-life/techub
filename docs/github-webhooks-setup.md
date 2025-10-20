## GitHub Webhooks (Optional, Simple Setup)

This is optional. TecHub runs fine without GitHub webhooks.

What webhooks add: faster “hot” updates to leaderboards when stars/watchers/pushes/releases happen.
Without them, daily/recurring jobs still rebuild leaderboards.

### TL;DR (Homer Simpson Safe)

1. In GitHub, set a webhook secret.
2. In TecHub, put the same secret into encrypted credentials.
3. Point GitHub to POST to our endpoint.
4. Done. If you skip, nothing breaks — just fewer “instant” updates.

### Where to configure in GitHub

Use either:

- GitHub App (recommended):
  - Settings → “Webhook” → set “Webhook secret” to something long.
  - Webhook URL: `https://YOUR_HOST/github/webhooks`.
  - Events: enable at least `star` (aka watch), `push`, and `release`.

- Classic org/repo webhook:
  - Settings → Webhooks → Add webhook.
  - Payload URL: `https://YOUR_HOST/github/webhooks`.
  - Content type: `application/json`.
  - Secret: same long secret as above.
  - Events: “Let me select individual events” → `Watch`, `Push`, `Release`.

### What to set in TecHub

- Add the same secret to Rails credentials:

```yaml
# config/credentials.yml.enc (via bin/rails credentials:edit)
github:
  webhook_secret: 'YOUR_LONG_SECRET'
```

- Or set env var: `GITHUB_WEBHOOK_SECRET=YOUR_LONG_SECRET`.

That’s it. Our endpoint `POST /github/webhooks` verifies `X-Hub-Signature-256` using HMAC with this
secret.

### Verifying it works

- Check Ops → Axiom Smoke or logs; you should see `leaderboard_rebuild`/`leaderboard_computed`
  shortly after events.
- You can test locally with a `curl` signed body if needed, but not required.

### What happens if you skip webhooks?

- Nothing breaks. Daily/recurring jobs rebuild leaderboards.
- Webhooks only make updates more “real-time”.

### Security notes

- The webhook secret is only for payload signature verification; it’s separate from Ops HTTP Basic
  auth.
- Keep `github.webhook_secret` in encrypted credentials (or env var) — never commit it.
