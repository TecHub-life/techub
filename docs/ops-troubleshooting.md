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

