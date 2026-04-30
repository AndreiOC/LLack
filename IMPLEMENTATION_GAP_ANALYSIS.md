# Implementation Gap Analysis

Generated: 2026-04-30

Re-audited against the current repository state on 2026-04-30, including the Phase 1 onboarding/provider-management changes.

Spec reviewed: `/root/.openclaw/workspace/FOSS_Chat_Implementation_Specification.md`

Repository reviewed: `/root/.openclaw/workspace/foss_chat`

## Audit Scope

- I read the full 1,134-line implementation specification and reviewed the repository end to end.
- Custom product logic is concentrated in `52` files under `lib/`, `2` SQL migration files under `assets/migrations/`, `pubspec.yaml`, platform manifests/entitlements, and `test/widget_test.dart`.
- The remaining `133` files under `android/`, `ios/`, `linux/`, `macos/`, `windows/`, and `web/` are mostly stock Flutter runner/generated scaffolding and static assets. They matter for platform readiness, but they do not add major product behavior beyond bootstrap and plugin registration.
- I could not run `flutter analyze` or `flutter test` because the `flutter` CLI is not installed in this environment.
- The original manual compile blocker in `lib/features/chat/chat_workspace.dart` has been fixed in this checkpoint by terminating the conversation action `switch` cases correctly.

## Summary

- Requirement-bearing top-level sections fully satisfied: `0/15`
- Detailed functional requirements fully satisfied: `11/33`
- Detailed functional requirements partially satisfied: `17/33`
- Detailed functional requirements not implemented: `5/33`
- Planning/reference sections `16-18` are informational only and excluded from completion counts.

### Fully Implemented Functional Requirements

- `FR-ONB-1` Welcome flow
- `FR-ONB-2` Secure API key entry
- `FR-ONB-3` Ollama auto-detection
- `FR-ONB-4` Skip onboarding / local only
- `FR-PRV-2` Provider configuration form
- `FR-PRV-3` Provider health check
- `FR-PRV-4` Default model selection
- `FR-PRV-6` Provider parameters
- `FR-CHT-6` Stop generation
- `FR-SWT-3` Provider indicator
- `FR-PLT-1` Responsive layout

### Not Implemented Functional Requirements

- `FR-CHT-4` Code block highlighting
- `FR-CHT-7` Edit message branching
- `FR-CNV-6` Export chat
- `FR-SWT-2` Quick model shortcuts
- `FR-PLT-3` Keyboard shortcuts

### Highest-Risk Gaps

- The local verification toolchain is still unavailable. `flutter` and `dart` are not installed in this environment, so static analysis and test execution remain blocked.
- Secret-handling is still incomplete around custom headers: `_HeadersEditor` stores arbitrary header values in SQLite via `providers.headers_json` and copies them into `outbox_jobs.payload_json`, so `Authorization`-style secrets can still be persisted outside secure storage.
- `FR-CHT-4`, `FR-CHT-7`, `FR-CNV-6`, `FR-SWT-2`, and `FR-PLT-3` are still unimplemented.
- Offline behavior is still storage-first rather than UX-complete: no global offline banner, queue-management surface, or explicit connectivity-restoration hook.
- Conversation operations remain incomplete: rename UI, search/FTS, delete undo/retention purge, and export are still missing.
- Logging/redaction, TLS policy enforcement, notifications, and meaningful test coverage are still absent.

## Current Implementation Footprint

### Already Fully or Mostly Built

- Flutter app shell and Riverpod bootstrap: `lib/main.dart:9-182`
- SQLite bootstrap and migrations: `lib/data/db/database_config.dart:7-294`, `assets/migrations/001_initial_schema.sql:1-138`, `assets/migrations/002_migration.sql:1-21`
- Secure storage backed API key handling: `lib/platform/secure_storage/secure_storage_service.dart:1-58`, `lib/data/repositories/provider_repository.dart:32-167`
- Core entities and DAOs for providers, conversations, messages, outbox jobs, app settings, and usage snapshots: `lib/domain/entities/*.dart`, `lib/data/db/dao/*.dart`
- Ollama and OpenAI-compatible adapters with streaming: `lib/data/services/adapters/ollama_adapter.dart:11-388`, `lib/data/services/adapters/openai_compatible_adapter.dart:11-454`
- Three-page onboarding plus shared schema-driven provider editor: `lib/features/onboarding/onboarding_flow.dart`, `lib/features/providers/provider_editor_sheet.dart`, `lib/app/providers/onboarding_provider.dart`
- Dedicated provider management sheet with add/edit/delete/undo, health refresh, and fallback deletion handling: `lib/features/providers/provider_management_sheet.dart`, `lib/app/providers/provider_management_provider.dart`
- Basic chat UI, conversation list, send/stream/stop flow: `lib/features/chat/chat_workspace.dart:11-1158`, `lib/app/providers/chat_state_provider.dart:24-611`, `lib/data/services/chat_service.dart:12-423`
- Usage aggregation and dashboard baseline: `lib/data/services/usage_service.dart:6-333`, `lib/features/chat/usage_dashboard_sheet.dart:8-456`
- Offline outbox polling baseline: `lib/data/services/outbox_service.dart:9-174`

### Partially Built

- Provider CRUD now has a real management surface, but repository-level multi-entity transaction hardening is still incomplete for destructive flows that reassign conversations and soft delete a provider in two separate writes.
- Conversation list supports pin/archive/delete and pull-to-refresh, but not rename, search, export, or undo: `lib/app/providers/conversation_list_provider.dart:12-70`, `lib/features/chat/chat_workspace.dart:258-481`
- Offline support still lacks a global banner, queue inspection UI, and explicit connectivity-restoration retries.

### Not Built

- Dedicated settings feature
- Search UI and FTS
- Export feature
- Keyboard shortcuts
- Local notifications
- Structured logging/redaction
- Integration and meaningful widget/unit test coverage

## Detailed Per-Section Breakdown

## 1. Product Definition

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `1.1 Product Summary` | Partial | Local-first persistence, provider abstraction, chat UI, streaming, and offline outbox baseline exist in `lib/data/services/chat_service.dart:12-423`, `lib/data/services/outbox_service.dart:9-174`, `lib/features/chat/chat_workspace.dart:11-1158`. | Offline degradation, provider management, and full history operations are incomplete. |
| `1.2 Release Intent` | Partial | Baseline features are partly implemented; some expansion work has started early, especially usage tracking in `lib/data/services/usage_service.dart:80-333`. | Baseline is not complete, and expansion items are unevenly implemented. |
| `1.3 Supported Platforms` | Partial | Android, iOS, Windows, macOS, and Linux project scaffolding exists; desktop DB handling is in `lib/data/db/database_config.dart:12-24`; Android/iOS/macOS local-networking permissions and entitlements are now configured in the platform manifests. | Web scaffolding still ships even though the spec defers web, and local build verification is blocked by the missing Flutter/Dart toolchain in this environment. |
| `1.4 Goals` | Partial | Minimal setup, local persistence, provider switching, streaming, cancellation, and secure secret storage exist in `lib/features/onboarding/onboarding_flow.dart:119-824`, `lib/data/repositories/provider_repository.dart:32-167`, `lib/app/providers/chat_state_provider.dart:119-265`. | Recovery from temporary connectivity loss is only partial, and provider switching/model UX is incomplete. |
| `1.5 Non-Goals For Release 1` | Partial | There is no collaboration, sync, attachments, multimodal, or tool-calling code. | Web scaffolding still ships in `web/index.html:1-38` and `web/manifest.json:1-35`, even though web-first deployment is a non-goal. |
| `1.6 Technology Baseline` | Partial | Most listed packages are declared in `pubspec.yaml:9-91`. | `flutter_riverpod` is `^2.6.1`, not the spec baseline `^3.3.1`; `flutter_html` is not declared; SDK baseline is `>=3.0.0`, not explicitly `3.19+`. |
| `1.7 Supporting Package Set` | Partial | Many expected packages are declared in `pubspec.yaml:35-69`. | Several are unused in app code: `workmanager`, `flutter_local_notifications`, `hotkey_manager`, `pdf`, `share_plus`, `flutter_highlight`, `smooth_page_indicator`, `flutter_svg`, `dropdown_button2`, `flutter_slidable`, `pull_to_refresh`, `network_info_plus`. |

## 2. Implementation Corrections Derived From Investigation

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `2.1 Database Support` | Complete | `DatabaseConfig.initialize()` switches to `sqflite_common_ffi` on Windows/Linux and uses `path_provider` for DB location in `lib/data/db/database_config.dart:12-24`. | No material gap in this item. |
| `2.2 Secret Storage` | Complete | Secrets are written to `flutter_secure_storage` in `lib/platform/secure_storage/secure_storage_service.dart:18-58`, and only `api_key_ref` is stored in SQLite via `lib/data/repositories/provider_repository.dart:45-67`. | No custom AES layer exists. |
| `2.3 Background Sync` | Partial | Foreground polling and lifecycle-triggered retry exist in `lib/main.dart:127-157` and `lib/data/services/outbox_service.dart:40-169`. | `workmanager` is not used, connectivity-restoration retry is not explicit, and there is no queued-job manual retry UI. |
| `2.4 Responsive Layout` | Complete | The app uses standard Material widgets plus `LayoutBuilder`, a drawer on narrow screens, and split panes on wide screens in `lib/features/chat/chat_workspace.dart:68-209`, `lib/features/onboarding/onboarding_flow.dart:68-115`. | No dependency on `flutter_adaptive_scaffold`. |
| `2.5 Notifications` | Not | `flutter_local_notifications` is declared in `pubspec.yaml:65-66`. | No notification service, initialization, or alert dispatch exists in app code. |
| `2.6 Connectivity Assumptions` | Partial | `connectivity_plus` is used only as an offline signal in `lib/app/providers/chat_state_provider.dart:507-513`; adapter calls also have send/receive timeouts in both adapters. | There is no robust provider-call retry policy beyond outbox handling, and no global offline banner. |

## 3. Solution Overview

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `3.1 Architecture Style` | Partial | The code is layered into `app/providers`, `domain/entities`, `data/db`, `data/repositories`, `data/services`, `platform/secure_storage`, and `features/*`. | The boundaries are thin in places; controllers/use cases are not separated, and UI still owns some orchestration. |
| `3.2 Core Modules` | Partial | Implemented modules: app shell, onboarding, provider management, chat, conversation list baseline, offline outbox, and usage dashboard. | Missing or incomplete: export, search, settings, notifications, keyboard shortcuts, and deeper conversation-management/search flows. |
| `3.3 Recommended Project Structure` | Partial | The repo follows the general layered shape and now includes `features/providers/`. | Missing recommended directories/modules such as `bootstrap/`, `core/`, `data/models/`, `domain/enums/`, `domain/usecases/`, `features/conversations/`, `features/settings/`, `features/usage/`, `platform/background/`, and `platform/notifications/`. |

## 4. Functional Scope

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `4.1 Primary User Journeys` | Partial | First-run onboarding, recent conversations, send/stream/stop, and basic offline queuing are implemented in `lib/features/onboarding/onboarding_flow.dart:119-824`, `lib/features/chat/chat_workspace.dart:258-1044`, `lib/app/providers/chat_state_provider.dart:119-245`. | Search, rename, export, archive recovery, provider comparison workflows, and explicit offline banner/sync states are missing. |
| `4.2 Release Scope` | Partial | Onboarding, secure API-key handling, Ollama detection, provider management, validation, model selection, send/stream/stop, usage, and responsive layout are present. | Baseline gaps remain in code highlighting, better model-switching UX, offline UX, conversation operations, keyboard shortcuts, and testing. |

## 5. Data Model

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `5.1 Domain Entities` | Complete | All required entities exist: `Provider`, `ProviderModel`, `Conversation`, `Message`, `OutboxJob`, `UsageSnapshot`, `AppSetting` under `lib/domain/entities/`. | No material gap in entity presence. |
| `5.2 Provider Entity` | Complete | `lib/domain/entities/provider.dart:3-224` contains all required fields, storage mapping, health status enum, and soft-delete support. | No material gap in the entity itself. |
| `5.3 ProviderModel Entity` | Complete | `lib/domain/entities/provider_model.dart:1-106` contains all required fields and storage mapping. | No material gap in the entity itself. |
| `5.4 Conversation Entity` | Complete | `lib/domain/entities/conversation.dart:1-111` contains required IDs, provider/model selection, pin/archive/delete timestamps, and timestamps. | No material gap in the entity itself. |
| `5.5 Message Entity` | Complete | `lib/domain/entities/message.dart:3-225` contains required fields including `edited_from_message_id`, `generation_group_id`, usage, errors, and metadata. | No material gap in the entity itself. |
| `5.6 OutboxJob Entity` | Complete | `lib/domain/entities/outbox_job.dart:17-185` contains required fields, status enum, retry count, next retry time, and error text. | No material gap in the entity itself. |
| `5.7 AppSetting Entity` | Complete | `lib/domain/entities/app_setting.dart:3-94` and migration defaults in `assets/migrations/001_initial_schema.sql:131-137` cover required keys. | No material gap in the entity itself. |
| `5.8 Initial SQLite Schema` | Complete | Required tables and recommended indexes exist in `assets/migrations/001_initial_schema.sql:5-137` and mirrored fallback SQL in `lib/data/db/database_config.dart:112-292`. | The schema also adds `usage_snapshots`, which is extra but consistent with later usage features. |
| `5.9 Migration Strategy` | Partial | Forward-only migration files exist and mobile/desktop share the same logical schema path via `DatabaseConfig.onCreate/onUpgrade` in `lib/data/db/database_config.dart:26-68`. | `databaseVersion` starts at `2`, not `1` (`lib/data/db/database_config.dart:9-10`); `001_initial_schema.sql` is not idempotent; the fallback `_executeInitialSchema()` inserts `null` into `NOT NULL` `app_settings.value_json` for two keys (`lib/data/db/database_config.dart:278-291`). |

## 6. Provider Abstraction

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `6.1 Adapter Contract` | Partial | `ChatProviderAdapter` exists in `lib/domain/interfaces/chat_provider_adapter.dart:93-111`, with validation, model fetch, health check, stream, and completion methods. | The interface shape does not match the spec exactly. `streamChat` and `completeChat` require a separate `apiKey` argument, and there is no provider-schema abstraction in this layer. |
| `6.2 Supported Provider Types In Release 1` | Complete | The adapter factory in `lib/data/services/adapters/adapter_factory.dart:7-20` supports `ollama` and `openai_compatible`. | No material gap in provider type support. |
| `6.3 Ollama Rules` | Complete | Default local probe endpoints and Bonjour discovery are in `lib/app/providers/ollama_discovery_provider.dart:71-221`; health/model probing hits `/api/tags` and chat hits `/api/chat` in `lib/data/services/adapters/ollama_adapter.dart:23-261`; Android/iOS/macOS local-network permissions are configured in the platform manifests. | No material gap in the Ollama rule implementation itself. |
| `6.4 OpenAI-Compatible Rules` | Partial | `/models` and `/chat/completions` are used in `lib/data/services/adapters/openai_compatible_adapter.dart:23-301`; API keys are required by UI validation and adapter calls. | Streaming normalizes SSE only. The spec explicitly asks for provider-specific NDJSON fallback too, and that path is not implemented. |
| `6.5 Provider Schema Definition` | Complete | Provider schema/value objects exist in `lib/domain/entities/provider_configuration_schema.dart`, and the shared editor renders both provider types from that schema in `lib/features/providers/provider_editor_sheet.dart`. | No material gap in the schema definition itself. |

## 7. Request, Streaming, and Offline Pipeline

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `7.1 Send Message Flow` | Partial | Input/provider/model checks happen in `lib/app/providers/chat_state_provider.dart:119-163`; user + assistant placeholder messages are inserted together via `lib/data/repositories/message_repository.dart:33-63`; assistant status transitions to `streaming` in `lib/data/services/chat_service.dart:147-148`; partial content is buffered and finalized with usage in `lib/data/services/chat_service.dart:150-236`. | New-conversation creation plus first message send are not wrapped as one transaction, and there is no explicit application-layer send transaction boundary beyond the message batch. |
| `7.2 Streaming Rules` | Partial | UI deltas are applied in memory in `lib/app/providers/chat_state_provider.dart:380-407`; DB writes are throttled to `300 ms` in `lib/data/services/chat_service.dart:167-177`; cancellation preserves partial output via `cancelMessage()` and reload in `lib/app/providers/chat_state_provider.dart:255-265`. | The UI update cadence is not configurable/tested to the spec target, and stream lifecycle observability is missing. |
| `7.3 Offline Queue Rules` | Partial | Only remote providers are queued when offline or on retryable remote failure in `lib/app/providers/chat_state_provider.dart:154-163`, `237-246`, `523-610`; outbox jobs retry with exponential backoff in `lib/data/db/dao/outbox_job_dao.dart:76-95`; polling retries on launch/resume in `lib/main.dart:131-157` and `lib/data/services/outbox_service.dart:40-169`. | No explicit connectivity-restoration trigger, no `workmanager`, and no queued-job manual retry controls in the UI. |
| `7.4 Error Categories` | Partial | Typed chat errors exist in `lib/domain/errors/chat_errors.dart:1-81`, and adapters map Dio/status errors into these types in both adapter files. | The app does not centralize user copy, log severity, retry eligibility, and UI CTA mapping per category. There is no structured logging layer. |

## 8. Security and Privacy Requirements

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `API keys never written to SQLite/shared prefs/logs/exports` | Partial | The dedicated API-key field persists only `api_key_ref` in SQLite (`lib/domain/entities/provider.dart:80-96`) and stores the real key in secure storage (`lib/platform/secure_storage/secure_storage_service.dart:33-46`). | `_HeadersEditor` allows secret-like headers to be entered as plain text (`lib/features/providers/provider_editor_sheet.dart:1261-1349`), `Provider.toJson()` persists those values in `headers_json` (`lib/domain/entities/provider.dart:80-96`), and `_enqueueToOutbox()` copies `providerHeaders` into `outbox_jobs.payload_json` (`lib/app/providers/chat_state_provider.dart:572-585`). |
| `Secrets masked in forms and confirmation screens` | Partial | The dedicated API-key field is masked and has a reveal toggle in `lib/features/providers/provider_editor_sheet.dart:315-387`, and the delete confirmation dialog does not display secret values in `lib/features/providers/provider_management_sheet.dart:473-547`. | Custom-header values are always rendered as plain text inputs in `lib/features/providers/provider_editor_sheet.dart:1307-1333`, so secret-like headers are not masked. |
| `Sensitive headers redacted in logs` | Not | No logging system exists. | No redaction utilities or log tests exist. |
| `Exports exclude provider secrets/raw headers` | Not | No export feature exists. | The requirement is unimplemented because the feature is unimplemented. |
| `Local-only mode supported` | Complete | Local-only mode is persisted in app settings and onboarding state via `lib/app/providers/onboarding_provider.dart:45-69`. | No material gap in the persistence flag itself. |
| `Deleting a provider deletes the secure storage secret when no longer referenced` | Partial | Permanent deletion removes the secure-storage key in `lib/data/repositories/provider_repository.dart:170-173`, and provider deletion confirmation exists in `lib/features/providers/provider_management_sheet.dart:473-547`. | The normal delete flow is still a soft delete for undo, so the secret remains in secure storage after deletion, and there is no reference-counting or delayed secret-purge policy. |

## 9. Detailed Functional Requirements

### 9.1 Onboarding And Setup

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-ONB-1 Welcome Flow` | Complete | Onboarding now checks both provider and conversation counts in `lib/app/providers/onboarding_provider.dart:15-32,86-99`; the UI is a three-page flow with next/skip/setup behavior and page-resume persistence in `lib/features/onboarding/onboarding_flow.dart:16-99,334-456`. | No material gap in the baseline welcome flow. |
| `FR-ONB-2 Secure API Key Entry` | Complete | API-key entry is masked with a reveal toggle and replace/remove behavior in `lib/features/providers/provider_editor_sheet.dart:280-347`; provider saves roll back secure-storage mutations if the SQLite write fails in `lib/data/repositories/provider_repository.dart:32-118,186-207`. | No material gap in the baseline secure-entry flow. |
| `FR-ONB-3 Ollama Auto-Detection` | Complete | Discovery probes common local endpoints and Bonjour candidates in `lib/app/providers/ollama_discovery_provider.dart:71-221`; every candidate is HTTP validated via `lib/data/services/adapters/ollama_adapter.dart:23-51`; last successful endpoint is persisted in `lib/app/providers/onboarding_provider.dart:57-77`. | No material gap in the baseline auto-detection flow. |
| `FR-ONB-4 Skip Onboarding / Local Only` | Complete | The setup page exposes an explicit local-only completion path and persistent local-only preference in `lib/features/onboarding/onboarding_flow.dart:212-331`; completion persists through `lib/app/providers/onboarding_provider.dart:65-77`. | No material gap in the baseline local-only path. |

### 9.2 Provider Management

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-PRV-1 Provider CRUD` | Partial | Dedicated list/detail/editor flows now exist in `lib/features/providers/provider_management_sheet.dart` and `lib/features/providers/provider_editor_sheet.dart`; safe delete with fallback and undo restore are wired through `lib/app/providers/provider_management_provider.dart:44-95`. | The destructive path that reassigns conversations and soft-deletes the provider is still two sequential repository writes rather than one explicit SQLite transaction boundary. |
| `FR-PRV-2 Provider Configuration Form` | Complete | The shared provider editor renders fields from `ProviderConfigurationSchemas` in `lib/features/providers/provider_editor_sheet.dart:72-426`, validates headers and URLs, and supports duplicate-key prevention plus shared rendering for both provider types. | No material gap in the baseline form engine. |
| `FR-PRV-3 Provider Health Check` | Complete | Health checks refresh opportunistically on app start with a five-minute cache in `lib/app/providers/provider_management_provider.dart:17-32,144-214`; save and manual refresh flow through the shared editor and management sheet, and explanatory health text is shown in both list and detail surfaces. | No material gap in the baseline health-check flow. |
| `FR-PRV-4 Default Model Selection` | Complete | Default model selection exists in the shared editor, models can be fetched on demand, stale selections refresh before save, and new conversations still inherit the provider default through `lib/app/providers/chat_state_provider.dart:133-148`. | No material gap in the baseline default-model flow. |
| `FR-PRV-5 Custom Ollama Endpoint` | Partial | Manual Ollama endpoint entry and discovery-based candidate selection exist in the shared editor, and provider cards now classify endpoints as local/LAN/remote in `lib/features/providers/provider_management_sheet.dart`. | Save is still not hard-gated on a successful probe of a custom endpoint. |
| `FR-PRV-6 Provider Parameters` | Complete | The shared editor exposes `temperature`, `max_tokens`, and `top_p`, validates numeric ranges, and supports reset-to-defaults in `lib/features/providers/provider_editor_sheet.dart:430-554`; adapters already apply the saved settings to outbound requests. | No material gap in the baseline provider-parameter flow. |

### 9.3 Chat Interface

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-CHT-1 Send / Receive Messages` | Partial | The composer auto-resizes with `minLines: 1` and `maxLines: 6` in `lib/features/chat/chat_workspace.dart:999-1025`; double-submit protection exists in `_isSending` and streaming guards in `212-225` and `lib/app/providers/chat_state_provider.dart:125-131`; user messages are stored before streaming begins via `lib/data/repositories/message_repository.dart:33-63`. | Send is not visually disabled for empty input, keyboard-shortcut send is absent, and immediate focus-management behavior is not implemented. |
| `FR-CHT-2 Streaming Responses` | Partial | Assistant messages stream incrementally in `lib/app/providers/chat_state_provider.dart:345-407`; provider chunk formats are normalized in both adapters; completion/cancellation/failure states are distinct in `lib/domain/entities/message.dart:176-188` and `lib/features/chat/chat_workspace.dart:932-944`. | The UI update cadence is not configurable to the spec target, and there is no explicit long-output performance test coverage. |
| `FR-CHT-3 Markdown Rendering` | Partial | Messages render through `MarkdownBody` with a controlled style sheet in `lib/features/chat/chat_workspace.dart:875-890`. | No explicit HTML sanitization/constrained fallback layer exists, and there is no custom rendering for tables, links, or advanced Markdown states. |
| `FR-CHT-4 Code Block Highlighting` | Not | `flutter_highlight` is declared in `pubspec.yaml:53-55`. | There is no syntax-highlighting renderer, no copy button per block, and no line-number setting in the chat UI. |
| `FR-CHT-5 New Conversation` | Partial | Users can start a fresh thread from the conversation rail button in `lib/features/chat/chat_workspace.dart:312-316`; the chat state resets via `lib/app/providers/chat_state_provider.dart:103-106`. | The conversation record is not created until the first send, there is no FAB/menu/keyboard shortcut path, and focus handoff to the composer is not implemented. |
| `FR-CHT-6 Stop Generation` | Complete | Stop is exposed in the composer in `lib/features/chat/chat_workspace.dart:1028-1037`; cancellation calls through `lib/app/providers/chat_state_provider.dart:255-265` and `lib/data/services/chat_service.dart:263-270`; partial content remains stored. | No material gap in the stop flow itself. |
| `FR-CHT-7 Edit Message` | Not | The schema contains `edited_from_message_id` and `generation_group_id` in `lib/domain/entities/message.dart:13-20` and `assets/migrations/001_initial_schema.sql:65-66`. | There is no UI or service logic for editing a prior message, creating a new branch, or marking later messages superseded. |

### 9.4 Conversation Management

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-CNV-1 Conversation List` | Partial | Pinned-first sorting and pagination APIs exist in `lib/data/db/dao/conversation_dao.dart:10-33`; the UI supports pin/archive/delete and pull-to-refresh in `lib/features/chat/chat_workspace.dart:333-470`. | The UI does not actually use paginated/incremental loading, and there is no performance verification for `1000+` conversations. |
| `FR-CNV-2 Persistent History` | Partial | Conversation/message persistence is SQLite-backed across restarts via DAOs and repositories; foreign keys are enabled in `lib/app/providers/database_provider.dart:12-17`. | Not all write paths are explicitly transaction-safe at the application level, and crash-recovery/integrity checks are missing. |
| `FR-CNV-3 Delete Conversation` | Partial | Soft delete is implemented with `deleted_at` in `lib/data/db/dao/conversation_dao.dart:62-71`, and deleted conversations are excluded from list queries in `10-33`. | There is no undo window, no `30`-day purge policy, and no deleted-conversation recovery UI. |
| `FR-CNV-4 Rename Conversation` | Partial | DAO/repository support title updates in `lib/data/db/dao/conversation_dao.dart:117-126` and `lib/data/repositories/conversation_repository.dart:45-48`. | There is no rename UI, and manual-title vs auto-title behavior is not tracked. |
| `FR-CNV-5 Search History` | Partial | Basic title and message `LIKE` search helpers exist in `lib/data/db/dao/conversation_dao.dart:155-164` and `lib/data/db/dao/message_dao.dart:176-185`. | No unified search feature, no FTS5, no debounce, no snippets, and no highlighting. |
| `FR-CNV-6 Export Chat` | Not | `pdf` and `share_plus` are declared in `pubspec.yaml:60-63`. | No export service, UI, file generation, or sanitization exists. |

### 9.5 Provider Switching

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-SWT-1 Provider Selector` | Partial | The chat header exposes a provider dropdown in `lib/features/chat/chat_workspace.dart:651-685`, and conversation provider selection is persisted in `lib/app/providers/chat_state_provider.dart:315-343` and `lib/data/db/dao/conversation_dao.dart:128-145`. | There is no search in the selector, no model selector, and no unavailable-provider expansion state. |
| `FR-SWT-2 Quick Model Shortcuts` | Not | `provider_models.last_used_at` is tracked in storage and touched on completion in `lib/data/services/chat_service.dart:222-225`. | No recent-model chips or shortcut UI exists. |
| `FR-SWT-3 Provider Indicator` | Complete | The chat header shows provider name and model context in `lib/features/chat/chat_workspace.dart:653-703,978-983`, and the provider control is interactive. | No material gap in the indicator itself. |
| `FR-SWT-4 Switch Mid-Chat` | Partial | Users can change provider before the next send via the header dropdown, and conversation text history is reused by `lib/app/providers/chat_state_provider.dart:184-205` and `lib/data/services/chat_service.dart:322-345`. | There is no visible system divider for provider/model switches, and model switching is incomplete. |

### 9.6 Cost Tracking

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-CST-1 Token Counting` | Partial | Provider-reported usage is preferred in `lib/data/services/chat_service.dart:198-205`; fallback estimation uses a character heuristic in `406-412`; per-message usage is stored via `212-220`. | The fallback is not tokenizer-based, and there is no explicit `estimated` flag on message records. |
| `FR-CST-2 Usage Dashboard` | Partial | Daily/weekly/monthly aggregation, local vs cloud split, and provider breakdown exist in `lib/data/services/usage_service.dart:134-244`; the sheet UI exists in `lib/features/chat/usage_dashboard_sheet.dart:16-456`. | No "money saved" metric, no charting, and no reconciliation tests exist. |
| `FR-CST-3 Spending Alerts` | Partial | Monthly threshold persistence and single-crossing banner state exist in `lib/data/services/usage_service.dart:158-205,287-306`; the in-app banner is in `lib/features/chat/chat_workspace.dart:730-814`. | No local notification dispatch exists, and the app does not suggest local alternatives after alerting. |

### 9.7 Platform And Offline

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-PLT-1 Responsive Layout` | Complete | Mobile drawer layout and desktop split-pane layout are implemented with deterministic breakpoints in `lib/features/chat/chat_workspace.dart:68-209`, `651-723`, and in onboarding `68-115`, `312-500`. | No material gap in the core responsive shell behavior. |
| `FR-PLT-2 Offline Support` | Partial | Remote sends queue while offline in `lib/app/providers/chat_state_provider.dart:154-163,523-610`; outbox backoff/polling is in `lib/data/services/outbox_service.dart:29-169`; queued state is visible in message status labels in `lib/features/chat/chat_workspace.dart:932-944`. | There is no global online/offline banner, no explicit connectivity-restoration trigger, and no queue-management screen. |
| `FR-PLT-3 Keyboard Shortcuts` | Not | `hotkey_manager` is declared in `pubspec.yaml:68-69`. | No shortcut registration or desktop-specific shortcut handling exists in app code. |

## 10. User Interface Specification

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `10.1 App Shell` | Partial | Onboarding, conversation list, chat detail, provider management, and usage dashboard now exist across `lib/features/onboarding/onboarding_flow.dart`, `lib/features/chat/chat_workspace.dart`, `lib/features/providers/provider_management_sheet.dart`, and `lib/features/chat/usage_dashboard_sheet.dart`. | Settings is still missing. |
| `10.2 Navigation Model` | Partial | Mobile uses a drawer, desktop uses persistent list + detail, usage is shown as a modal sheet, and provider management/editor/delete confirmation flows now exist as modals. | Rename dialog, export sheet, and broader settings navigation are still missing. |
| `10.3 Conversation Title Rules` | Partial | Titles derive from the first user message via `lib/data/services/chat_service.dart:38-60,355-359`. | There is no explicit-user-title precedence logic, no manual rename tracking, and no later auto-title suppression after rename. |
| `10.4 Status UI States` | Partial | Message states are shown in `lib/features/chat/chat_workspace.dart`; first-run/loading/empty-state flows exist in `lib/main.dart` and `lib/features/chat/chat_workspace.dart`; provider health state is now surfaced in provider list/detail UI. | Global offline and syncing states are still not rendered explicitly. |

## 11. Non-Functional Requirements

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `11.1 Performance` | Partial | DB indexes and throttled streaming writes exist in `assets/migrations/001_initial_schema.sql:92-120` and `lib/data/services/chat_service.dart:167-177`. | No measured targets, no large-transcript profiling, and no paginated message/conversation UI usage. |
| `11.2 Reliability` | Partial | Messages are persisted before transport in `lib/data/repositories/message_repository.dart:33-63`; failures surface as `failed`, `queued`, or `cancelled` states. | No integrity checks, no crash-recovery tooling, and no end-to-end reliability tests exist. |
| `11.3 Security` | Partial | Secure storage is used for the dedicated API-key field, and provider metadata is separated from secure-storage references. | Remote HTTPS/TLS is not enforced for non-local endpoints, there is no insecure-local-development opt-in flow, no log/header redaction layer exists, and custom-header secrets can still be persisted in SQLite and outbox payloads. |
| `11.4 Accessibility` | Partial | The app uses standard Material controls and mostly text-labeled states. | There is no explicit accessibility audit, no dedicated semantics work, and no test coverage for screen readers/touch targets. |
| `11.5 Observability` | Not | No logging/telemetry module exists in `lib/`. | No structured categories, no debug request tracing, and no stream lifecycle tracing exist. |

## 12. Testing Strategy

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `12.1 Unit Tests` | Not | No repository, adapter, validation, usage, or retry unit tests exist. | Entire section is missing. |
| `12.2 Widget Tests` | Partial | There is one smoke test in `test/widget_test.dart:13-20` that only checks that `MaterialApp` builds. | No onboarding, provider form, conversation list, chat composer, or Markdown rendering widget tests exist. |
| `12.3 Integration Tests` | Not | No integration test directory or flows exist. | Entire section is missing. |
| `12.4 Manual Test Matrix` | Not | No manual test matrix or QA checklist exists in the repo. | Entire section is missing. |

## 13. Delivery Plan And Phase Gates

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `13.1 Phase 0: Foundation` | Partial | Flutter bootstrap, shell, and database bootstrap exist in `lib/main.dart:9-182` and `lib/data/db/database_config.dart:7-294`. | Logging and environment/config scaffolding are missing; platform readiness is incomplete. |
| `13.2 Phase 1: Core Persistence And Provider Setup` | Partial | Three-page onboarding, local-only completion, secure API-key handling, shared schema-driven provider forms, provider CRUD UI, health checks, and default model selection are now implemented across `lib/features/onboarding/onboarding_flow.dart`, `lib/features/providers/`, and the provider repositories/notifiers. | Repository-level transaction hardening for provider deletion/fallback flows and local analyze/test verification are still incomplete. |
| `13.3 Phase 2: Core Chat` | Partial | Conversation creation, send/stream/stop, adapters, and persistence exist in `lib/data/services/chat_service.dart:32-423` and `lib/app/providers/chat_state_provider.dart:119-265`. | Code highlighting, better retry UX, and stronger reliability/testing are missing. |
| `13.4 Phase 3: Conversation Operations` | Partial | Conversation list, pin/archive/delete, and provider selector baseline exist. | Rename, stable management UX, search, and provider-selector search/model switching are missing. |
| `13.5 Phase 4: Responsive And Offline Behavior` | Partial | Responsive split-pane and outbox polling baseline exist. | Offline banner, retry observability, and platform-specific connectivity handling are incomplete. |
| `13.6 Phase 5: Expansion Features` | Partial | Provider parameters (`FR-PRV-6`) are implemented, usage dashboard/thresholds are started, and data model support for branching exists. | Remaining expansion gaps include stricter custom-Ollama endpoint gating, edit branching, search, export, keyboard shortcuts, recent-model shortcuts, and provider-switch dividers. |
| `13.7 Phase 6: Usage And Alerts` | Partial | Usage aggregation and in-app threshold banners exist. | Notifications, alert suggestions, and test reconciliation are missing. |

## 14. Critical Path

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `14. Critical Path` | Partial | Platform bootstrap, network permissions/entitlements, DB layer, secure storage, provider adapters, provider management, conversation persistence, send/stream/stop, and responsive shell are present. | Offline queue observability, conversation operations, and local build/test verification are still incomplete. |

## 15. Risk Register

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `15.1 Provider API Variance` | Partial | Variance is normalized through adapter classes in `lib/data/services/adapters/*.dart`. | No provider-specific regression tests exist, and OpenAI-compatible NDJSON fallback is missing. |
| `15.2 Background Work On Desktop` | Partial | The code treats foreground polling as the baseline in `lib/data/services/outbox_service.dart:40-169`. | There is no explicit desktop-specific lifecycle/connectivity integration beyond timers. |
| `15.3 History Branching Complexity` | Partial | `generation_group_id` and `edited_from_message_id` are in the schema/entity. | Superseded-message handling and edit/regenerate UX are not implemented. |
| `15.4 Large Transcript Performance` | Partial | Message persistence is throttled, and the UI uses `ListView.separated`. | There is no pagination in the chat UI, no syntax-highlight optimization, and no performance tests for large transcripts. |
| `15.5 Secret Handling Regressions` | Not | No redaction utility or redaction tests exist. | The mitigation named in the spec is unimplemented. |

## 16. Estimated Delivery Effort

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `16. Estimated Delivery Effort` | Informational | This section is a planning estimate, not a code requirement. | No implementation status to verify. |

## 17. Feature Coverage Matrix

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `17. Feature Coverage Matrix` | Informational | This section is a cross-reference matrix for the spec. | No implementation status to verify directly. |

## 18. Implementation Start Checklist

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `18. Implementation Start Checklist` | Informational | This section is a pre-coding checklist. | The repo shows these decisions were not cleanly closed before implementation; several checklist items are still open in the codebase. |

## Prioritized TODO List

1. Critical blockers in the repository are complete.
   Fixed in this checkpoint: the chat action switch fall-through, Android networking/cleartext config, iOS ATS/local-network/Bonjour keys, macOS outbound network entitlements, and the missing provider-management/onboarding foundation in app code.
   Remaining external blocker: `flutter` and `dart` are not installed in this environment, so local analyze/test verification is still unavailable.

2. Close the current secret-handling gaps before expanding more provider features.
   Treat `Authorization`/`api-key` style headers as secrets, keep them out of SQLite and `outbox_jobs.payload_json`, add masking/redaction for secret-like header values, and enforce the spec’s TLS vs local-development policy.

3. Finish baseline chat UX requirements.
   Add disabled send-state UX for empty input, proper new-conversation creation semantics, searchable provider/model selection, and code block rendering with syntax highlight and copy actions.

4. Complete offline UX, not just offline storage.
   Add global online/offline banners, queued-job visibility, manual retry controls, and explicit connectivity-restoration retry hooks.

5. Finish conversation operations.
   Implement rename UI, search UI with FTS5, soft-delete undo/retention purge, and export in Markdown/JSON/PDF with secret-safe serialization.

6. Implement history branching before expanding editing features.
   The data model already contains `generation_group_id`; now add edit-message branching, superseded-message handling, and active-branch filtering.

7. Finish provider switching and model selection UX.
   Add recent model chips, a model selector, provider/model change dividers in the transcript, and hidden/unavailable provider handling.

8. Add observability.
   Introduce structured logging categories, debug-only request tracing, stream lifecycle events, and tests that assert secrets never appear in persisted/exported/logged content.

9. Build the test suite the spec expects.
   Start with repository/migration tests, adapter normalization tests, onboarding/provider/chat widget tests, and at least one streamed chat integration test with offline-queue retry coverage.
