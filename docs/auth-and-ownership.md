GitHub Login, Ownership, and Accounts

Login

- Entry point: `/auth/github` (SessionsController).
- Uses GitHub OAuth; on return we validate state, fetch the authenticated user, and store the user
  id in the Rails session.
- Secrets via env or `config/credentials.yml.enc` (see README.md and `rake credentials:example`).

Ownership and accounts

- A profile has exactly one owner.
- First ownership: if a profile has no owner, the first submitter becomes the owner.
- No non-owner links: we no longer create non-owner links on submission.
- Rightful owner: if someone else owns a profile and the rightful owner (matching GitHub login)
  later submits their own profile, they become the owner and all other links are removed.
- Duplicate submissions by non-owners are rejected.
- Admins (via `/ops/ownerships` or rake) may transfer ownership or set owner for true orphans.
- Limits: enforce a per-user cap (default 5) on total profiles to control abuse/costs.
- Eligibility: enforce `Eligibility::GithubProfileScoreService` threshold on new submissions to
  control costs.

My Profiles

- The `My Profiles` page shows only profiles you own (`is_owner: true`).
- When the rightful owner claims a profile, we remove any stale links to other users and show a
  one-time banner to those users explaining the removal.
- Owner badge is not shown in `My Profiles` (ownership is implicit there).

Ownership scenarios

- First-time self-claim: If you submit your own GitHub login and no owner exists, you become the
  owner.
- Non-rightful submit allowed when no owner: If you submit a profile that doesn’t match your login
  and no owner exists, you become the owner (first-come, first-served).
- Rightful owner later claims: If someone else owns it and the rightful owner submits their own
  login later, ownership transfers to them and other links are removed.
- Duplicate submission by non-owner when already owned: Rejected; ownership does not change.
- Admin transfer: In `/ops/ownerships`, transferring sets the new owner and removes all other links
  for that profile.

Actions after claim

- Refresh data from GitHub.
- Run card synthesis.
- Enqueue screenshots (OG/Card/Simple) and view asset URLs.

FAQ

- What does "single owner" mean? A profile always has exactly one owner.
- Can I add profiles I don't own? You can submit any public profile. If it exists already and you
  are not the rightful owner, we reject the submission. If you are the rightful owner, you'll take
  ownership automatically.
- Do owners have special permissions? Admin-only actions remain behind `/ops`.
