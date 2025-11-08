# Integration Layer Refactor Plan

## Purpose

We have mixed third-party wrappers (configuration, clients, adapters) with TecHub-specific
services inside `app/services/<vendor>/`. This document is the source of truth for fixing that
anti-pattern across the entire project.

## Guiding Principles

1. **Integration layer is thin and isolated.** It owns provider-specific payloads, auth, retries,
   and response normalization. It does not reach into TecHub models, jobs, or storage.
2. **Application services consume the integration layer.** They live in domain-specific folders
   (`app/services/profiles/`, `app/services/avatars/`, etc.) and never talk directly to Faraday,
   raw env vars, or provider schemas.
3. **Every integration follows the same structure.** Configuration + client + adapters + helpers
   under `app/integrations/<vendor>/`, with tests and documentation.

_Implementation note:_ we keep existing module names (`Gemini::Configuration`, `Github::AppClientService`, etc.) for compatibility; only the filesystem roots change. Domain services move out of those namespaces entirely (e.g., `Avatars::AvatarPromptService`).

## File-by-File Destination Map

| Current Path | Future Path | Notes |
| --- | --- | --- |
| `app/services/gemini/configuration.rb` | `app/integrations/gemini/configuration.rb` | Pure provider config; no app deps. |
| `app/services/gemini/client_service.rb` | `app/integrations/gemini/client_service.rb` | Faraday/auth wrapper only. |
| `app/services/gemini/endpoints.rb` | `app/integrations/gemini/endpoints.rb` | No change besides namespace. |
| `app/services/gemini/providers/adapter.rb` | `app/integrations/gemini/adapters/adapter.rb` | Same for `ai_studio_adapter.rb` and `vertex_adapter.rb`. |
| `app/services/gemini/response_helpers.rb` | `app/integrations/gemini/response_helpers.rb` | Shared helper used by wrappers only. |
| `app/services/gemini/schema_helpers.rb` | `app/integrations/gemini/schema_helpers.rb` | Single source for schema transforms. |
| `app/services/gemini/image_generation_service.rb` | `app/integrations/gemini/image_generation_service.rb` | Integration-only: builds payload + Faraday call. |
| `app/services/gemini/image_description_service.rb` | `app/integrations/gemini/image_description_service.rb` | Same logic, new home. |
| `app/services/gemini/text_generation_service.rb` | `app/integrations/gemini/text_generation_service.rb` | |
| `app/services/gemini/structured_output_service.rb` | `app/integrations/gemini/structured_output_service.rb` | |
| `app/services/gemini/healthcheck_service.rb` | `app/integrations/gemini/healthcheck_service.rb` | Thin wrapper to test provider availability. |
| `app/services/gemini/image_generation_healthcheck_service.rb` | `app/integrations/gemini/image_generation_healthcheck_service.rb` | Same pattern. |
| `app/services/gemini/avatar_prompt_service.rb` | `app/services/avatars/avatar_prompt_service.rb` | Domain logic; depends on integration façade. |
| `app/services/gemini/avatar_image_suite_service.rb` | `app/services/avatars/avatar_image_suite_service.rb` | Domain orchestrator; uses prompt + integration façade. |
| `app/services/gemini/image_generation_service_test.rb` (and other tests) | `test/integrations/gemini/...` | Mirrors integration placement. |
| `app/services/github/configuration.rb` | `app/integrations/github/configuration.rb` | Same pattern as Gemini. |
| `app/services/github/app_client_service.rb` | `app/integrations/github/app_client_service.rb` | Issues installation tokens; no domain deps. |
| `app/services/github/fetch_pinned_repos_service.rb` | `app/services/profiles/fetch_pinned_repos_service.rb` | Domain-specific (TecHub) service; depend on integration façade. |
| `app/services/github/profile_summary_service.rb` | `app/services/profiles/profile_summary_service.rb` | Domain service. |
| `app/services/github/profile_sync_service.rb` (and similar) | `app/services/profiles/...` | Every service that manipulates TecHub data leaves the integration namespace. |
| `storage/` services that wrap Spaces SDK (`app/services/storage/active_storage_upload_service.rb`, etc.) | (Future) move any direct SDK usage to `app/integrations/spaces/`; today only ActiveStorage abstractions exist, so files remain under `app/services/storage`. |
| `lib/telemetry/axiom_*` (actual paths to be enumerated) | `app/integrations/axiom/...` | Build façade for logging/export. |
| `app/services/resend/...` (email senders) | (Future) move to `app/integrations/resend/...`; current implementation is initializer-only. |

_Action: run `rg -n "module Gemini" -g '*.rb'`, `rg -n "module Github" -g '*.rb'`, `rg -n "Resend"`, etc., and extend this table until every file is accounted for._

## Migration Checklist

1. **Create Integration Roots**
   - Add `app/integrations/` with subdirectories per vendor.
   - Update `config/application.rb` (or initializers) so Zeitwerk autoloads the new namespace.

2. **Move Existing Wrappers**
   - Relocate Gemini files that only talk to the API (`configuration.rb`, `client_service.rb`,
     `endpoints.rb`, `providers`, `response_helpers.rb`, `schema_helpers.rb`,
     `image_generation_service.rb`, `text_generation_service.rb`,
     `image_description_service.rb`, `structured_output_service.rb`).
   - Mirror the same move for GitHub (`configuration.rb`, `app_client_service.rb`,
     `rest_client_service.rb`, webhook helpers).
   - Repeat for Axiom (telemetry exporters), DigitalOcean Spaces (storage clients + credential
     helpers), Resend (email delivery wrappers), and any other third-party integrations
     discovered by `rg -g '*.rb' 'Axiom'` / `Spaces` / `Resend`, etc.

3. **Wire Autoloading**
   - Ensure `app/integrations` is on both autoload and eager load paths so Zeitwerk resolves the same module constants from the new directory.
   - Fix references anywhere that relied on old file locations (tasks, tests, docs).

4. **Extract Façade Methods**
   - Where multiple application services reuse the same integration call, add light wrapper methods
     (e.g., `Gemini::ImageGenerationService.generate(prompt:, …)` or a tiny module) so callers never
     touch Faraday directly.
   - Ensure these helpers return structured hashes/`ServiceResult`s so application code never looks
     at raw responses.

5. **Relocate Application Workflows**
   - Move services like `Avatars::AvatarImageSuiteService` into domain folders (e.g.,
     `app/services/avatars/avatar_image_suite_service.rb`) and rename modules accordingly.
   - Ensure they depend on the integration façade, not low-level adapters.

6. **Deduplicate Helpers**
   - Consolidate JSON parsing, schema translation, and endpoint building into shared helpers inside
     the integration layer. Delete duplicated versions scattered across services.

7. **Update Tests**
   - Add unit tests for each integration façade (mock Faraday).
   - Update existing service tests to stub the façade rather than low-level classes.
   - Keep configuration tests in sync with renamed files.

8. **Docs & Philosophy**
   - Reference this plan directly from `docs/integrations.md` or the ops playbook—no ADR, this is rectifying drift.
   - Document the rule that integration directories contain only wrappers so the philosophy is explicit.

9. **Repeat For Every Vendor**
   - Use `rg -g '*.rb' 'module .*::Configuration'` and `rg -g '*.rb' 'Axiom\|Spaces\|Resend'`
     to discover other integrations (Mission Control, logging sinks, etc.) and migrate them
     using the same steps.

## Vendor-Specific Work Plans

### Gemini

| Work Item | Current Location | Future Location / Outcome |
| --- | --- | --- |
| Configuration class | `app/services/gemini/configuration.rb` | `app/integrations/gemini/configuration.rb` |
| Client service | `app/services/gemini/client_service.rb` | `app/integrations/gemini/client_service.rb` |
| Endpoint builder | `app/services/gemini/endpoints.rb` | `app/integrations/gemini/endpoints.rb` |
| Provider adapters | `app/services/gemini/providers/*` | `app/integrations/gemini/providers/*` |
| Response helpers | `app/services/gemini/response_helpers.rb` | `app/integrations/gemini/response_helpers.rb`; all other classes include via module. |
| Schema helpers | `app/services/gemini/schema_helpers.rb` | `app/integrations/gemini/schema_helpers.rb`; remove duplicate copies. |
| Image generation | `app/services/gemini/image_generation_service.rb` | `app/integrations/gemini/image_generation_service.rb`; supports `Gemini::ImageGenerationService.call` from its new home. |
| Image description | `app/services/gemini/image_description_service.rb` | `app/integrations/gemini/image_description_service.rb`. |
| Text generation | `app/services/gemini/text_generation_service.rb` | `app/integrations/gemini/text_generation_service.rb`. |
| Structured output | `app/services/gemini/structured_output_service.rb` | `app/integrations/gemini/structured_output_service.rb`. |
| Healthchecks | `app/services/gemini/healthcheck_service.rb`, `app/services/gemini/image_generation_healthcheck_service.rb` | `app/integrations/gemini/healthcheck_service.rb`, `app/integrations/gemini/image_generation_healthcheck_service.rb`. |
| Avatar prompt | `app/services/gemini/avatar_prompt_service.rb` | `app/services/avatars/avatar_prompt_service.rb` (namespace change only). |
| Avatar suite | `app/services/gemini/avatar_image_suite_service.rb` | `app/services/avatars/avatar_image_suite_service.rb`. |
| Tests | `test/services/gemini/*` | `test/integrations/gemini/*` or relevant domain test paths after namespace changes. |

Verification: run existing Gemini doctors/smokes (list them) plus service tests after relocation; ensure dev server endpoints (`/gemini/up`, `/gemini/image`) still return 200.

### GitHub

| Work Item | Current Location | Future Location / Outcome |
| --- | --- | --- |
| Configuration | `app/services/github/configuration.rb` | `app/integrations/github/configuration.rb`. |
| App client (installation token) | `app/services/github/app_client_service.rb` | `app/integrations/github/app_client_service.rb`. |
| App authentication JWT | `app/services/github/app_authentication_service.rb` | `app/integrations/github/app_authentication_service.rb`. |
| Webhook verification | `app/services/github/webhook_verification_service.rb` | `app/integrations/github/webhook_verification_service.rb`. |
| OAuth/token exchange helpers | `app/services/github/user_oauth_service.rb`, `app/services/github/fetch_authenticated_user.rb` | `app/integrations/github/user_oauth_service.rb`, `app/integrations/github/fetch_authenticated_user.rb`. |
| Domain services (profile summary, avatar download, webhook dispatch) | `app/services/github_profile/*` | namespaced as `GithubProfile::*` to avoid confusion with integration wrappers. |
| Tests | move to `test/integrations/github/*` plus domain tests. |

Verification: run GitHub doctors (app client doctor, webhook doctor) and regression tests for profile sync pipeline.

### DigitalOcean Spaces

_Current state:_ only `Storage::ActiveStorageUploadService` and `Storage::ServiceProfile` exist, both of which wrap ActiveStorage. Once we introduce a direct Spaces client, migrate it per the table below.

| Work Item | Current Location | Future Location / Outcome |
| --- | --- | --- |
| Storage client wrappers (ActiveStorage upload helper, direct Spaces client) | `app/services/storage/active_storage_upload_service.rb`, `app/services/storage/*spaces*.rb` | `app/integrations/spaces/upload.rb`, `client.rb`. |
| Credential helpers | anywhere referencing `Spaces` env vars | move into `Integrations::Spaces::Configuration`. |
| Domain consumers (avatar uploads, asset records) | leave under `app/services/storage/` or `app/services/avatars/`; depend on façade. |

Verification: run storage doctor / upload tests, ensure generated assets still upload.

### Axiom

| Work Item | Current Location | Future Location / Outcome |
| --- | --- | --- |
| Telemetry exporter | `lib/telemetry/axiom_logger.rb` (example) | `app/integrations/axiom/logger.rb`. |
| Configuration | move env/credential lookup into `app/integrations/axiom/configuration.rb`. |
| Domain hooks (OpsContext, instrumentation) | remain in app directories; call façade. |

Verification: run telemetry doctor/log smoke (if missing, add one) to confirm events reach Axiom.

### Resend

_Current state:_ email delivery is configured via `config/initializers/mailer.rb` and Action Mailer; there is no dedicated wrapper yet. When we add one, follow the table below.

| Work Item | Current Location | Future Location / Outcome |
| --- | --- | --- |
| API key/config | `app/services/resend/configuration.rb` (if present) or inline env lookups | `app/integrations/resend/configuration.rb`. |
| Client wrapper | `app/services/resend/send_email_service.rb` | `app/integrations/resend/client.rb`. |
| Domain mailers/jobs | `app/services/notifications/*`, `app/mailers/*` | keep in place; depend on façade. |

Verification: run email doctor (send test email) + keep mailer tests.

### Mission Control / Other Vendors

| Work Item | Current Location | Future Location / Outcome |
| --- | --- | --- |
| Mission Control client/config | locate under `config/initializers` or `app/services/mission_control` | move wrappers to `app/integrations/mission_control`. |
| Any additional SDK (StatusPage, analytics) | map and migrate using same pattern. |

Verification: run relevant doctors (mission control heartbeat, status push) or create them if missing.

## Implementation Order

1. Gemini (largest drift, proves the pattern).
2. GitHub (mirrors Gemini, high impact).
3. Storage + Mission Control + any remaining integrations.

## Done Definition

- No application service lives under `app/integrations/`.
- No integration code reaches into `ActiveRecord`, `Storage::*`, or feature flags.
- All external calls originate from façade methods with tests.
- Developer docs explain how to add new integrations using this structure.
