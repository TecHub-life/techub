Mission Control (Jobs UI)

Setup

- Add gem (next infra PR):
  - Gemfile: gem "mission_control-jobs"
  - bundle install

Routes (mount) Add the following to `config/routes.rb`. Auth is enforced in
`config/initializers/mission_control_jobs.rb`.

```ruby
if defined?(MissionControl::Jobs::Engine)
  cred = Rails.application.credentials.dig(:mission_control, :jobs, :http_basic)
  basic = Rails.env.production? ? cred : (ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] || cred)

  if Rails.env.production?
    mount MissionControl::Jobs::Engine, at: "/ops/jobs" if basic.present?
  else
    mount MissionControl::Jobs::Engine, at: "/ops/jobs"
  end
end
```

Credentials

- Use `.env` or `config/credentials.yml.enc` to supply HTTP Basic in the form `user:password`.
  - .env (dev): `MISSION_CONTROL_JOBS_HTTP_BASIC=user:password`
  - Credentials (prod): `mission_control.jobs.http_basic: user:password`
  - A sample is included in `rake credentials:example`.

Usage

- Visit `/ops/jobs` to see queues, retry failures, and manually enqueue.
- Use `rake "screenshots:enqueue_all[login]"` to batch enqueue the OG/Card/Simple jobs.

Generate credentials

- Generate a strong password:
  - `openssl rand -base64 24`
- Set env var (example):
  - `export MISSION_CONTROL_JOBS_HTTP_BASIC=techub:$(openssl rand -base64 24)`
- Or add to credentials:
  - `bin/rails credentials:edit` and add: mission_control: jobs: http_basic:
    techub:your-strong-password
