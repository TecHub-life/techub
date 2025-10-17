# Ownerships Admin – Definitions, Invariants, Current State, and Plan

## Definitions

- PROFILE: Techub profile identified by `profiles.login` (e.g., `@octocat`).
- USER: Authenticated GitHub account identified by `users.login`.
- LINK: `ProfileOwnership` record connecting a USER to a PROFILE. One link per PROFILE is
  `is_owner=true`.

## Invariants (required)

1. Each PROFILE must have exactly one owner (`is_owner=true`).
2. Admins cannot clear/delete the owner link. Ownership changes only via transfer.
3. Linking a USER whose login matches the PROFILE login sets them owner and removes other links
   (auto-owner).

## Current State (as of today)

- Enforced invariants in model and controller (no owner clear/delete; transfer endpoint).
- Ops UI currently shows a single selected PROFILE with:
  - Owner display
  - Transfer owner dropdown (all users, current owner shown disabled)
  - Linked users list with Remove
  - Link user dropdown (all users)

## Gaps to fix

- Need an All Profiles table view showing every PROFILE in one place.
- Need inline transfer and link actions per row.
- Need pagination and simple filters (profile login, owner login).
- Link user should use a searchable picker (not a massive dropdown).

## Plan

1. All Profiles table (replace current single-panel by default)
   - Columns: Profile, Owner, Linked count, Actions
   - Actions menu per row: Transfer (opens small inline select or modal), Link user, View details
   - Click Profile opens full profile page; click Owner opens GitHub user

2. Filters & pagination
   - Filters: profile login contains, owner login contains
   - Pagination: 50 per page (server-side)

3. Transfer flow
   - Inline control: select from linked users, or open user search to pick any user
   - POST /ops/ownerships/:id/transfer

4. Link flow
   - User search modal with typeahead hitting `/ops/users/search?q=`
   - POST /ops/ownerships/link (auto-owner if login == profile login)

5. Details view (optional follow-up)
   - Per-profile page with full linked users list and ownership history

## Acceptance Criteria

- Table lists all profiles with current owner (no JS needed to read the data).
- Transfer owner in ≤3 clicks from the table.
- Link user in ≤3 clicks from the table.
- Owner can never be cleared or deleted; transfer is mandatory.
