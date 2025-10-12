---
name: Bug Report (with pinpointing)
about: Report a defect with enough context to pinpoint failure fast
labels: bug
---

## Summary

What’s broken and how you noticed.

## Stage / Area

- [ ] Eligibility
- [ ] GitHub Sync
- [ ] Manual Repos (submitted)
- [ ] Manual URL Scrape
- [ ] Prompting (Gemini)
- [ ] Card Synthesis
- [ ] Screenshots (Puppeteer)
- [ ] Uploads

Reference: docs/debugging-guide.md for where to look and artifacts.

## Repro Steps

Exact steps and inputs. Include flags set and environment.

## Expected vs Actual

What you expected; what happened.

## Artifacts / Logs

- Relevant service logs (service/status/error)
- Paths under public/generated/<login>/meta/ (if prompting-related)
- DB rows involved (e.g., profile_scrapes, profile_repositories)

## Impact / Severity

Who is affected and how bad it is.
