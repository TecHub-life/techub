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

Copy-friendly output (no pager, easy paste)

- Disable colors where supported (reduces ANSI noise in terminals/copy):
  - One-off: prefix with `NO_COLOR=1` (many tools respect it)
  - RuboCop no color: `bundle exec rubocop --no-color`
- Brakeman plain/JSON/Markdown, no pager:
  - Plain text to file + screen:
    `bundle exec brakeman -q --no-pager -w2 -f plain | tee tmp/brakeman.txt`
  - JSON to file: `bundle exec brakeman -q --no-pager -w2 -f json -o tmp/brakeman.json`
  - Markdown to file: `bundle exec brakeman -q --no-pager -w2 -f markdown -o tmp/brakeman.md`
- RuboCop simple/JSON:
  - Simple text: `bundle exec rubocop --no-color -f simple | tee tmp/rubocop.txt`
  - JSON to file: `bundle exec rubocop --no-color -f json -o tmp/rubocop.json`
- Tests to file + screen: `DISABLE_PARALLEL_TESTS=1 bin/rails test | tee tmp/test.txt`
- Strip ANSI colors if a tool insists on them:
  - `... | sed -r 's/\x1B\[[0-9;]*[mK]//g'`
  - or `... | perl -pe 's/\e\[[\d;]*[A-Za-z]//g'`
