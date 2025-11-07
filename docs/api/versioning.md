# TecHub API Versioning

This note explains how we interpret the version numbers that show up in our public API, what is
currently frozen, and what has to happen before we ship breaking changes.

---

## Two version numbers to keep straight

1. **Path namespace (`/api/v1/...`)** – identifies the overall family of endpoints. Consumers can
   expect similar authentication, pagination, and media types within a namespace, but the namespace
   itself does **not** guarantee a fully locked schema.
2. **OpenAPI `info.version` (`docs/api/openapi.yaml`)** – tracks the semantic version of the
   published contract. Today this is `0.1.0`, which means the API is still pre-stable per SemVer.
   While the namespace is already `v1`, the contract is explicitly marked experimental and breaking
   changes are allowed between `0.y.z` releases.

Until we bump the spec to `>= 1.0.0`, clients should treat `/api/v1/...` as “best effort stable”: we
avoid churn, but we reserve the right to change non-frozen fields when needed.

---

## What is frozen right now?

| Surface                                                        | Guarantee                                                                                                                         | Rationale                                                                                                                                                                                                                               |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/api/v1/battles/:username` and `/api/v1/battles/battle-ready` | Frozen schema. No new/renamed/removed keys without a coordinated version bump and doc update.                                     | Documented in `docs/api/battle-game-data.md` (“frozen profile endpoints”) and enforced by controller tests (`test/controllers/api/v1/battles/profiles_controller_test.rb`). Needed so the TecHub Battles client can cache aggressively. |
| `/api/v1/profiles/battle-ready` response                       | Field list enforced via `assert_superset`, so existing keys cannot disappear without test updates, but additive keys are allowed. | Keeps the public JSON contract stable enough for consumers while still letting us add optional data.                                                                                                                                    |

Everything else under `/api/v1/...` (profile details, assets, leaderboards, game-data, etc.) is
“stable but changeable”: we do our best to roll changes out carefully, but they are not formally
locked until we ship a `1.x` spec.

---

## What we can and cannot change today

| Change type                                              | Allowed while version is `0.y.z`? | Notes                                                                                                                                   |
| -------------------------------------------------------- | --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Add optional fields                                      | ✅                                | Preferred path. Update `docs/api/openapi.yaml`, markdown docs, and tests.                                                               |
| Change data types / rename fields (non-frozen endpoints) | ✅                                | Coordinate with consuming teams, call the change out in release notes, and bump the patch/minor within `0.y.z`.                         |
| Remove fields / break schema for frozen battle endpoints | ❌                                | Requires either a new endpoint (e.g., `/api/v2/battles/...`) or a major version bump (`1.0.0` or `2.0.0`).                              |
| Remove fields from other `/api/v1/...` endpoints         | ⚠️                                | Avoid unless unavoidable. Requires doc update, communication to consumers, and tests proving the new contract. Prefer additive changes. |

When in doubt, treat user-facing JSON as immutable and add new endpoints or flags rather than
repurposing existing ones.

---

## How and when to bump versions

1. **Breaking change planned?**
   - For battle endpoints: create `/api/v2/battles/...` or coordinate a major bump and migration
     plan.
   - For everything else: decide whether to (a) keep iterating within `0.y.z`, or (b) cut the first
     stable contract.
2. **Cutting `1.0.0`:**
   - Ensure every documented endpoint has controller/request specs that lock both required and
     optional fields.
   - Document the stability promise in this file and `docs/api/openapi.yaml`.
   - Update changelog/release notes and notify consumers.
3. **After `1.0.0`:**
   - Bug fixes → patch (`1.0.1`).
   - Backwards-compatible additions → minor (`1.1.0`).
   - Breaking changes → new major (`2.0.0`) and/or new URL namespace.

---

## Checklist for API changes

1. Update `docs/api/openapi.yaml` and any supporting markdown pages.
2. Add/adjust controller tests so the expected JSON shape is locked.
3. Note the change in release notes or the ops runbook so downstream consumers can react.
4. If the change is breaking, decide whether to ship it inside a new version (`1.0.0+`) or expose a
   new namespace/flag so existing clients keep working.

Documenting the policy here keeps the expectations in one place; refer to this file anytime you
consider changing `/api/v1/...`.
