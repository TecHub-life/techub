Mission Control (Jobs UI)

Setup

- Add gem (next infra PR):
  - Gemfile: gem "mission_control-jobs"
  - bundle install

Routes (guarded mount) Add the following to config/routes.rb to mount only when the gem is present.
Optional HTTP Basic guard uses env/credentials.

```ruby
if defined?(MissionControl::Jobs::Engine)
  basic = ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] || Rails.application.credentials.dig(:mission_control, :jobs, :http_basic)
  if basic.present?
    user, pass = basic.to_s.split(":", 2)
    authenticator = lambda do |u, p|
      ActiveSupport::SecurityUtils.secure_compare(u.to_s, user.to_s) & ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass.to_s)
    end
    constraints = lambda { |req| ActionController::HttpAuthentication::Basic.authenticate(req, &authenticator) }
    constraints(constraints) { mount MissionControl::Jobs::Engine, at: "/ops/jobs" }
  else
    mount MissionControl::Jobs::Engine, at: "/ops/jobs"
  end
end
```

Credentials

- Use `.env` or `config/credentials.yml.enc` to supply HTTP Basic in the form `user:password`.
  - .env: `MISSION_CONTROL_JOBS_HTTP_BASIC=user:password`
  - Credentials: mission_control.jobs.http_basic: user:password
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
