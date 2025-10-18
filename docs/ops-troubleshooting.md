Ops Troubleshooting

Logs

- Web logs (follow):
  ```bash
  cd /home/loftwah/gits/techub && bin/kamal logs
  ```
- Job worker logs (follow):
  ```bash
  cd /home/loftwah/gits/techub && bin/kamal logs -r job
  ```
- Last N lines:
  ```bash
  cd /home/loftwah/gits/techub && bin/kamal app logs --tail 200
  cd /home/loftwah/gits/techub && bin/kamal app logs --role job --tail 200
  ```
- Shell/console:
  ```bash
  cd /home/loftwah/gits/techub && bin/kamal shell
  cd /home/loftwah/gits/techub && bin/kamal console
  ```

Jobs UI (/ops/jobs)

- Protected with HTTP Basic in production. Set credentials and redeploy:
  ```bash
  export MISSION_CONTROL_JOBS_HTTP_BASIC='techub:$(openssl rand -base64 24)'
  cd /home/loftwah/gits/techub && bin/kamal deploy
  ```
- If using Rails credentials instead:
  ```bash
  bin/rails credentials:edit
  # add:
  # mission_control:
  #   jobs:
  #     http_basic: techub:<strong-password>
  ```

Health Checks

- App up: `/up`
- Gemini: `/up/gemini` and `/up/gemini/image`

Common Issues

- 406 on HEAD/allow_browser: benign for HEAD requests from crawlers; normal.
- No jobs running: confirm workers with `/ops/jobs` and tail job logs.
- Solid Queue in Puma: controlled by `SOLID_QUEUE_IN_PUMA` in `config/deploy.yml`.
- Screenshot command failed:
  - Ensure Node deps installed: `npm ci`.
  - Install Chromium libs on Linux/WSL:
    `sudo apt-get install -y libnss3 libatk-bridge2.0-0 libx11-xcb1 libdrm2 libgbm1 libasound2 libxcomposite1 libxrandr2 libxi6 fonts-liberation libxdamage1 libpango-1.0-0 libpangocairo-1.0-0 libcups2 libxkbcommon0`.
  - Verify URL is reachable (e.g., `http://127.0.0.1:3000/cards/<login>/og`).
  - Run locally for detailed stdout/stderr: `node script/screenshot.js --url ... --out ...`.
  - Check job logs; `Screenshots::CaptureCardService` logs stdout/stderr on failure.
- GitHub installation 404 creating access token:
  - Symptom: `POST https://api.github.com/app/installations/<id>/access_tokens: 404 - Not Found`.
  - Root cause: invalid/stale installation id OR the App has zero installations.
  - Pitfall: local `.env` setting `GITHUB_INSTALLATION_ID` overrides auto-discovery. Remove it unless intentionally pinning.
  - Fix:
    1) Ensure the App is installed (GitHub UI → Install App).
    2) Prefer leaving installation id unset in credentials/env; the app auto-discovers and caches it.
    3) In prod, POST `/ops/github/fix_installation` (HTTP Basic protected) to refresh the cached id.
    4) Validate from console: `Github::InstallationTokenService.call`.
