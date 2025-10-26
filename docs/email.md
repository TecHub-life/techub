# Email (Resend) Setup and Smoke Tests

## Prereqs

- Verify your sending domain in Resend (add DKIM per dashboard) so `notifications@techub.life` can
  send.
- Generate and copy your Resend API key.

## Configure credentials (zsh friendly)

```bash
# Open credentials using Cursor as the editor
EDITOR="cursor --wait" bin/rails credentials:edit
```

Add or update the following block:

```yaml
resend:
  api_key: re_xxxxxxxxxxxxxxxxxxxxxxxxx
```

## Delivery config (already wired)

- `config/initializers/mailer.rb` reads the key:
  `Resend.api_key = Rails.application.credentials.dig(:resend, :api_key)`
- `config/environments/development.rb`: `config.action_mailer.delivery_method = :resend`
- `config/environments/production.rb`: `config.action_mailer.delivery_method = :resend`
- Default sender: `TecHub <notifications@techub.life>` in `ApplicationMailer`.

## Smoke test: Rake (local or prod)

In zsh, quote the task to preserve brackets and commas:

```bash
bin/rake "email:smoke[to@example.com,Hello from TecHub]"
```

- Output includes a JSON `{ id: ..., to: ... }` on success.

## Smoke test: Ops panel (HTTP Basic protected in production)

- UI: Visit `/ops`, use "Email Smoke Test" form.
- cURL (production), replace creds and host:

```bash
curl -u 'techub:your-strong-password' \
  -X POST 'https://techub.life/ops/send_test_email' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data 'to=you@example.com&message=Hello%20from%20TecHub'
```

Auth details:

- Production: Ops endpoints require HTTP Basic if `mission_control.jobs.http_basic` exists in
  credentials; otherwise `/ops` returns 403.
- Development: Basic auth is optional; to enable, export
  `MISSION_CONTROL_JOBS_HTTP_BASIC="user:pass"` or add the same value to credentials.

## Does email affect profile creation?

- App notifications use `deliver_later` (async). Email failures will not block profile creation; at
  worst, the job fails later. The rake smoke task uses `deliver_now!` by design.

## Privacy: Email addresses

- OAuth now only requests `read:user` (no `user:email`). We do not read your email from GitHub.
- You can set or change your contact email at `Settings → Account`; it does not have to be your
  GitHub email.
- If you prefer not to share any email, leave it blank; profiles still work (you simply won’t
  receive emails).

## Troubleshooting

- Missing key → set `resend.api_key` in credentials and restart.
- Domain unverified → emails may be rejected or from-address rewritten; finish DKIM setup in Resend.
- Job not sending in prod → ensure workers are running and check `/ops/jobs`.

## Reference

- Resend Rails guide: https://resend.com/docs/send-with-rails
