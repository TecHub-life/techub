# Contributing

Keep it simple:

- Open an issue or PR with a clear title and a short description.
- Before pushing, run `bin/ci` locally (lint, security, tests).
- Small, focused changes beat large refactors.
- Follow existing conventions; prefer services/jobs over fat controllers.

Quick commands:

- Full local CI: `bin/ci`
- RuboCop: `bundle exec rubocop -A && bundle exec rubocop`
- Prettier check: `npm run prettier:check`
- Tests: `DISABLE_PARALLEL_TESTS=1 bin/rails test`
- Security (advisory): `bundle exec brakeman -q -w2`

That’s it. No templates. Thanks for contributing!
