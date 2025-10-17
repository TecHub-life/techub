GitHub Login, Ownership, and Accounts

Login

- Entry point: `/auth/github` (SessionsController).
- Uses GitHub OAuth; on return we validate state, fetch the authenticated user, and store the user
  id in the Rails session.
- Secrets via env or `config/credentials.yml.enc` (see README.md and `rake credentials:example`).

Ownership and accounts

- A profile has exactly one owner: the signed-in user whose GitHub login matches the profile's
  `login`.
- Other signed-in users can still link profiles to their account. They are not owners (no special
  permissions implied).
- Conflict resolution: if someone has linked a profile and the rightful owner later submits their
  own profile, we set them as the owner and remove all other links to that profile.
- My Profiles lists all profiles you’ve linked or own. If you are the owner, we show an "Owner"
  badge.
- Admins (via `/ops/ownerships` or rake) can set/clear the owner link in support situations.
- Limits: enforce a per-user cap (default 5) on total linked profiles to control abuse/costs.
- Eligibility: enforce `Eligibility::GithubProfileScoreService` threshold on new submissions to
  control costs.

Actions after claim

- Refresh data from GitHub.
- Run card synthesis.
- Enqueue screenshots (OG/Card/Simple) and view asset URLs.

FAQ

- What does "single owner" mean? There can be many links to a profile, but only one link is marked
  as the owner. The owner is the GitHub user whose `login` equals the profile's `login`.
- Can I add profiles I don't own? Yes. You can link any public profile. When the real owner submits
  their own profile, they become the owner and your link is removed.
- Do owners have special permissions? No. This flag is used to resolve ownership conflicts and to
  display the correct badge. Admin-only actions remain behind `/ops`.
