GitHub Login, Ownership, and Accounts

Login

- Entry point: `/auth/github` (SessionsController).
- Uses GitHub OAuth; on return we validate state, fetch the authenticated user, and store the user
  id in the Rails session.
- Secrets via env or `config/credentials.yml.enc` (see README.md and `rake credentials:example`).

Ownership and accounts

- Planned UX: after login, a “My Profiles” page lists claimed profiles.
- Users can:
  - Claim their own GitHub profile (match by login).
  - Add secondary GitHub logins they own.
  - Request ownership or removal of public profiles (verification flow; see FAQ).

Actions after claim

- Refresh data from GitHub.
- Run card synthesis.
- Enqueue screenshots (OG/Card/Simple) and view asset URLs.

FAQ

- We’ll adapt the TechDeck FAQ content for GitHub (free for TecHub): what it is, how it works,
  opt-out/ownership, anonymity, where data comes from, and how to use your card.
