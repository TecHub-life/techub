# Roadmap

## Now

- Finalise Loftwah's profile card presentation and wire it into the home page cache refresh flow.
- Polish OAuth onboarding copy and error states so GitHub sign-in feels trustworthy.
- Capture webhook payload metadata (workflow runs) and expose it in logs for debugging.

## Next

- Expand the directory into an actual listing fed by scheduled profile refreshes and search filters.
- Persist webhook insights so we can build leaderboards without re-fetching from GitHub.
- Ship a minimal admin dashboard for curating feature drops and card highlights.

## Later

- Integrate Stripe Checkout for paid card requests once the submission flow stabilises.
- Introduce notification emails (Resend) when cards are refreshed or new ones go live.
- Explore partner-facing analytics (export, API) once the data model hardens.
