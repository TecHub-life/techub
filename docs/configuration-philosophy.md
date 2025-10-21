# Configuration Philosophy

Use the right tool for the right kind of configuration:

- Durable, operator-controlled switches that must persist between deploys (e.g., cost controls,
  access gates): store in the database and manage via the Ops panel.
  - Example: `AppSetting` keys `open_access`, `allowed_logins`, `ai_images`,
    `ai_image_descriptions`.
- Secrets: keep in encrypted credentials (`config/credentials.yml.enc`) — not in `.env`.
- Environment tuning (hostnames, endpoints) that truly differs per environment: environment config
  or safe, minimal `.env` entries.

Guidelines:

- Avoid sprawl in `.env`. If a setting shouldn’t change per environment or needs a UI, make it a DB
  setting.
- Keep `.env` for local overrides and ephemeral CI needs; keep it small.
- Prefer convention and sensible defaults in code over configuration where possible.

In practice:

- AI image generation and avatar descriptions are controlled via DB-backed flags (Ops panel),
  default Off.
- User access allowlist and open-access toggle are DB-backed and survive deploys.
- Text/structured AI features depend on valid Gemini config; credentials live in encrypted config,
  not `.env`.
