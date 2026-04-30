# Implementation Gap Analysis

Generated: 2026-04-30
Re-audited: 2026-04-30 after major implementation pass

Spec reviewed: `/root/.openclaw/workspace/foss_chat/FOSS_Chat_Implementation_Specification.md`
Repository reviewed: `/root/.openclaw/workspace/foss_chat`

## Audit Scope

- Custom product logic is concentrated in `55` files under `lib/`, `3` SQL migration files under `assets/migrations/`, `pubspec.yaml`, platform manifests/entitlements, and `test/`.
- `flutter analyze` passes with **0 issues** and `flutter test` passes with **8 tests**.
- The `flutter` and `dart` CLIs are installed at `/opt/flutter/bin/`.

## Summary

- Requirement-bearing top-level sections fully satisfied: `3/15`
- Detailed functional requirements fully satisfied: `19/33`
- Detailed functional requirements partially satisfied: `11/33`
- Detailed functional requirements not implemented: `3/33`
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
- `FR-CHT-1` Send / Receive Messages (empty-input disable, Enter submit, focus handoff)
- `FR-CHT-4` Code block highlighting
- `FR-CHT-5` New Conversation (keyboard shortcut + focus handoff)
- `FR-CHT-6` Stop generation
- `FR-CHT-7` Edit message branching
- `FR-CNV-3` Delete Conversation (soft delete + undo SnackBar)
- `FR-CNV-4` Rename Conversation
- `FR-CNV-6` Export chat
- `FR-SWT-1` Provider Selector (model dropdown + recent-model chips)
- `FR-SWT-2` Quick model shortcuts
- `FR-SWT-3` Provider indicator
- `FR-PLT-1` Responsive layout
- `FR-PLT-2` Offline Support (global connectivity banner)
- `FR-PLT-3` Keyboard shortcuts

### Not Implemented Functional Requirements

- `FR-CNV-1` Conversation pagination / incremental loading (APIs exist, UI not wired)
- `FR-SWT-4` Switch mid-chat dividers in transcript
- `FR-CNV-5` Full FTS5 search with snippets/highlighting (basic title LIKE search implemented)

### Partially Satisfied Functional Requirements

- `FR-PRV-1` Provider CRUD — undo for providers exists; transaction hardening for destructive reassign still split across two writes
- `FR-PRV-5` Custom Ollama endpoint — save is not hard-gated on successful probe
- `FR-CHT-2` Streaming responses — UI cadence is not configurable/tested to spec target
- `FR-CHT-3` Markdown rendering — no HTML sanitization fallback or advanced table/link rendering
- `FR-CNV-2` Persistent history — not all writes are wrapped in explicit application transactions
- `FR-CNV-5` Search history — title search via LIKE exists; FTS5, message-content search, snippets, and highlighting are absent
- `FR-SWT-4` Switch mid-chat — provider/model switching works; transcript divider is absent
- `FR-CST-1` Token counting — fallback is character heuristic, not tokenizer-based
- `FR-CST-2` Usage dashboard — no "money saved" metric, no charting
- `FR-CST-3` Spending alerts — no local notification dispatch
- `FR-PLT-2` Offline support — banner exists; queued-job manual retry UI and connectivity-restoration retry hooks are absent

### Highest-Risk Gaps

- Secret-handling around custom headers is still incomplete: `_HeadersEditor` stores arbitrary header values in SQLite via `providers.headers_json` and copies them into `outbox_jobs.payload_json`.
- `FR-CNV-1` pagination is not wired to the conversation list UI.
- `FR-SWT-4` switch dividers are not rendered in the transcript.
- Logging/redaction, TLS policy enforcement, notifications, and integration test coverage are still absent.
- `workmanager` background retry is not wired up.

## Current Implementation Footprint

### Already Fully or Mostly Built

- Flutter app shell and Riverpod bootstrap: `lib/main.dart`
- SQLite bootstrap and migrations (now version 3): `lib/data/db/database_config.dart`, `assets/migrations/001_initial_schema.sql`, `assets/migrations/002_migration.sql`, `assets/migrations/003_add_superseded_status.sql`
- Secure storage backed API key handling: `lib/platform/secure_storage/secure_storage_service.dart`, `lib/data/repositories/provider_repository.dart`
- Core entities and DAOs for providers, conversations, messages, outbox jobs, app settings, and usage snapshots: `lib/domain/entities/*.dart`, `lib/data/db/dao/*.dart`
- Ollama and OpenAI-compatible adapters with streaming: `lib/data/services/adapters/ollama_adapter.dart`, `lib/data/services/adapters/openai_compatible_adapter.dart`
- Three-page onboarding plus shared schema-driven provider editor: `lib/features/onboarding/onboarding_flow.dart`, `lib/features/providers/provider_editor_sheet.dart`, `lib/app/providers/onboarding_provider.dart`
- Dedicated provider management sheet with add/edit/delete/undo, health refresh, and fallback deletion handling: `lib/features/providers/provider_management_sheet.dart`, `lib/app/providers/provider_management_provider.dart`
- Chat UI with code highlighting, edit branching, rename, search, export, model chips, keyboard shortcuts, offline banner, and responsive shell: `lib/features/chat/chat_workspace.dart`, `lib/features/chat/code_block_builder.dart`, `lib/features/chat/connectivity_banner.dart`, `lib/features/chat/export_service.dart`, `lib/features/chat/keyboard_shortcuts.dart`
- Usage aggregation and dashboard baseline: `lib/data/services/usage_service.dart`, `lib/features/chat/usage_dashboard_sheet.dart`
- Offline outbox polling baseline: `lib/data/services/outbox_service.dart`
- Settings screen: `lib/features/settings/settings_screen.dart`

### Partially Built

- Provider CRUD has a real management surface, but repository-level multi-entity transaction hardening is still incomplete for destructive flows that reassign conversations and soft delete a provider in two separate writes.
- Conversation list supports pin/archive/delete with undo, rename, search, pull-to-refresh, and export, but paginated/incremental loading is not wired to the UI.
- Offline support has a global banner; queued-job manual retry controls and explicit connectivity-restoration retry hooks are still missing.
- Search covers conversation titles via LIKE; FTS5, message-content search, snippets, and highlighting are absent.

### Not Built

- Local notifications (`flutter_local_notifications` is declared but unused)
- Structured logging/redaction
- Integration tests
- Manual test matrix / QA checklist
- Explicit 30-day retention purge scheduler (`purgeOldDeleted` DAO method exists but is not scheduled)
- Conversation/message pagination in the UI
- Provider/model switch dividers in the transcript

## Detailed Per-Section Breakdown

## 1. Product Definition

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `1.1 Product Summary` | Partial | Local-first persistence, provider abstraction, chat UI, streaming, offline outbox, code highlighting, edit branching, export, search, rename, model shortcuts, and responsive shell exist across `lib/features/chat/`. | Offline queue manual retry and large-transcript pagination are incomplete. |
| `1.2 Release Intent` | Partial | Baseline and expansion features are mostly implemented. Some items (notifications, integration tests) are deferred. | Baseline is close to complete; expansion items are unevenly implemented. |
| `1.3 Supported Platforms` | Partial | Android, iOS, Windows, macOS, and Linux project scaffolding exists; desktop DB handling is configured; Android/iOS/macOS local-networking permissions and entitlements are configured. | Web scaffolding still ships even though the spec defers web. |
| `1.4 Goals` | Partial | Minimal setup, local persistence, provider switching, streaming, cancellation, secure secret storage, and offline banner exist. | Recovery from temporary connectivity loss has a banner but lacks manual retry UI. |
| `1.5 Non-Goals For Release 1` | Partial | There is no collaboration, sync, attachments, multimodal, or tool-calling code. | Web scaffolding still ships. |
| `1.6 Technology Baseline` | Partial | Most listed packages are declared in `pubspec.yaml`. | `flutter_riverpod` is `^2.6.1`, not the spec baseline `^3.3.1`; `flutter_html` is not declared; SDK baseline is `>=3.0.0`, not explicitly `3.19+`. |
| `1.7 Supporting Package Set` | Partial | Many expected packages are declared in `pubspec.yaml`. | Several packages remain unused in app code: `workmanager`, `flutter_local_notifications`, `pdf`, `smooth_page_indicator`, `flutter_svg`, `dropdown_button2`, `flutter_slidable`, `pull_to_refresh`, `network_info_plus`. |

## 2. Implementation Corrections Derived From Investigation

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `2.1 Database Support` | Complete | `DatabaseConfig.initialize()` switches to `sqflite_common_ffi` on Windows/Linux and uses `path_provider` for DB location. | No material gap. |
| `2.2 Secret Storage` | Complete | Secrets are written to `flutter_secure_storage`; only `api_key_ref` is stored in SQLite. | No custom AES layer exists. |
| `2.3 Background Sync` | Partial | Foreground polling and lifecycle-triggered retry exist. | `workmanager` is not used; connectivity-restoration retry is not explicit; no queued-job manual retry UI. |
| `2.4 Responsive Layout` | Complete | Standard Material 3 widgets plus `LayoutBuilder`, drawer on narrow screens, split panes on wide screens. | No dependency on `flutter_adaptive_scaffold`. |
| `2.5 Notifications` | Not | `flutter_local_notifications` is declared in `pubspec.yaml`. | No notification service, initialization, or alert dispatch exists in app code. |
| `2.6 Connectivity Assumptions` | Partial | `connectivity_plus` drives the global offline banner; adapter calls have send/receive timeouts. | No robust provider-call retry policy beyond outbox handling. |

## 3. Solution Overview

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `3.1 Architecture Style` | Partial | Layered into `app/providers`, `domain/entities`, `data/db`, `data/repositories`, `data/services`, `platform/secure_storage`, and `features/*`. | Boundaries are thin in places; controllers/use cases are not separated; UI still owns some orchestration. |
| `3.2 Core Modules` | Partial | Implemented: app shell, onboarding, provider management, chat, conversation list, offline outbox, usage dashboard, export, search, settings. | Missing: notifications, keyboard shortcuts are present but basic, deeper conversation-management/search flows. |
| `3.3 Recommended Project Structure` | Partial | The repo follows the general layered shape and now includes `features/providers/` and `features/settings/`. | Missing recommended directories/modules such as `bootstrap/`, `core/`, `data/models/`, `domain/enums/`, `domain/usecases/`, `features/conversations/`, `features/usage/`, `platform/background/`, and `platform/notifications/`. |

## 4. Functional Scope

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `4.1 Primary User Journeys` | Partial | First-run onboarding, recent conversations, send/stream/stop, code highlighting, edit branching, export, rename, search, model shortcuts, offline banner, and basic offline queuing are implemented. | Archive recovery, provider comparison workflows, and explicit queued-job retry are missing. |
| `4.2 Release Scope` | Partial | Onboarding, secure API-key handling, Ollama detection, provider management, validation, model selection, send/stream/stop, code highlighting, edit branching, export, rename, search, usage, keyboard shortcuts, offline banner, and responsive layout are present. | Baseline gaps remain in transcript dividers, FTS5 search, pagination, notifications, and integration testing. |

## 5. Data Model

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `5.1 Domain Entities` | Complete | All required entities exist: `Provider`, `ProviderModel`, `Conversation`, `Message`, `OutboxJob`, `UsageSnapshot`, `AppSetting` under `lib/domain/entities/`. | No material gap. |
| `5.2 Provider Entity` | Complete | `lib/domain/entities/provider.dart` contains all required fields, storage mapping, health status enum, and soft-delete support. | No material gap. |
| `5.3 ProviderModel Entity` | Complete | `lib/domain/entities/provider_model.dart` contains all required fields and storage mapping. | No material gap. |
| `5.4 Conversation Entity` | Complete | `lib/domain/entities/conversation.dart` contains required IDs, provider/model selection, pin/archive/delete timestamps, and timestamps. | No material gap. |
| `5.5 Message Entity` | Complete | `lib/domain/entities/message.dart` contains required fields including `edited_from_message_id`, `generation_group_id`, usage, errors, and metadata. `MessageStatus.superseded` was added. | No material gap. |
| `5.6 OutboxJob Entity` | Complete | `lib/domain/entities/outbox_job.dart` contains required fields, status enum, retry count, next retry time, and error text. | No material gap. |
| `5.7 AppSetting Entity` | Complete | `lib/domain/entities/app_setting.dart` and migration defaults cover required keys. | No material gap. |
| `5.8 Initial SQLite Schema` | Complete | Required tables and recommended indexes exist in `assets/migrations/001_initial_schema.sql` and mirrored fallback SQL in `lib/data/db/database_config.dart`. | The schema also adds `usage_snapshots`, which is extra but consistent with later usage features. |
| `5.9 Migration Strategy` | Partial | Forward-only migration files exist and mobile/desktop share the same logical schema path via `DatabaseConfig.onCreate/onUpgrade`. Migration `003_add_superseded_status.sql` recreates the messages table to add `superseded` to the CHECK constraint. | `001_initial_schema.sql` is not idempotent; migration `003` uses the standard SQLite table-recreation pattern because SQLite does not support `ALTER TABLE DROP CONSTRAINT`. |

## 6. Provider Abstraction

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `6.1 Adapter Contract` | Partial | `ChatProviderAdapter` exists in `lib/domain/interfaces/chat_provider_adapter.dart` with validation, model fetch, health check, stream, and completion methods. | The interface shape does not match the spec exactly. `streamChat` and `completeChat` require a separate `apiKey` argument. |
| `6.2 Supported Provider Types In Release 1` | Complete | The adapter factory supports `ollama` and `openai_compatible`. | No material gap. |
| `6.3 Ollama Rules` | Complete | Default local probe endpoints and Bonjour discovery; health/model probing hits `/api/tags` and chat hits `/api/chat`; local-network permissions are configured. | No material gap. |
| `6.4 OpenAI-Compatible Rules` | Partial | `/models` and `/chat/completions` are used; API keys are required by UI validation and adapter calls. | Streaming normalizes SSE only. Provider-specific NDJSON fallback is not implemented. |
| `6.5 Provider Schema Definition` | Complete | Provider schema/value objects exist in `lib/domain/entities/provider_configuration_schema.dart`, and the shared editor renders both provider types. | No material gap. |

## 7. Request, Streaming, and Offline Pipeline

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `7.1 Send Message Flow` | Partial | Input/provider/model checks, user + assistant placeholder insertion, streaming status transition, and partial buffering/finalization exist. | New-conversation creation plus first message send are not wrapped as one transaction. |
| `7.2 Streaming Rules` | Partial | UI deltas are applied in memory; DB writes are throttled to `300 ms`; cancellation preserves partial output. | The UI update cadence is not configurable/tested to the spec target, and stream lifecycle observability is missing. |
| `7.3 Offline Queue Rules` | Partial | Only remote providers are queued when offline or on retryable remote failure; outbox jobs retry with exponential backoff; polling retries on launch/resume. | No explicit connectivity-restoration trigger, no `workmanager`, and no queued-job manual retry controls in the UI. |
| `7.4 Error Categories` | Partial | Typed chat errors exist in `lib/domain/errors/chat_errors.dart`, and adapters map Dio/status errors into these types. | The app does not centralize user copy, log severity, retry eligibility, and UI CTA mapping per category. There is no structured logging layer. |

## 8. Security and Privacy Requirements

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `API keys never written to SQLite/shared prefs/logs/exports` | Partial | The dedicated API-key field persists only `api_key_ref` in SQLite and stores the real key in secure storage. Export service does not include provider secrets or headers. | `_HeadersEditor` allows secret-like headers to be entered as plain text; `Provider.toJson()` persists those values in `headers_json`; `_enqueueToOutbox()` copies `providerHeaders` into `outbox_jobs.payload_json`. |
| `Secrets masked in forms and confirmation screens` | Partial | The dedicated API-key field is masked and has a reveal toggle. | Custom-header values are always rendered as plain text inputs, so secret-like headers are not masked. |
| `Sensitive headers redacted in logs` | Not | No logging system exists. | No redaction utilities or log tests exist. |
| `Exports exclude provider secrets/raw headers` | Complete | `ExportService.toMarkdown` and `ExportService.toJson` only export conversation title, messages, and model IDs. No secrets or headers are included. | No material gap. |
| `Local-only mode supported` | Complete | Local-only mode is persisted in app settings and onboarding state. | No material gap. |
| `Deleting a provider deletes the secure storage secret when no longer referenced` | Partial | Permanent deletion removes the secure-storage key; provider deletion confirmation exists. | The normal delete flow is still a soft delete for undo, so the secret remains in secure storage after deletion, and there is no reference-counting or delayed secret-purge policy. |

## 9. Detailed Functional Requirements

### 9.1 Onboarding And Setup

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-ONB-1 Welcome Flow` | Complete | Onboarding checks both provider and conversation counts; the UI is a three-page flow with next/skip/setup behavior and page-resume persistence. | No material gap. |
| `FR-ONB-2 Secure API Key Entry` | Complete | API-key entry is masked with a reveal toggle and replace/remove behavior; provider saves roll back secure-storage mutations if the SQLite write fails. | No material gap. |
| `FR-ONB-3 Ollama Auto-Detection` | Complete | Discovery probes common local endpoints and Bonjour candidates; every candidate is HTTP validated; last successful endpoint is persisted. | No material gap. |
| `FR-ONB-4 Skip Onboarding / Local Only` | Complete | The setup page exposes an explicit local-only completion path and persistent local-only preference. | No material gap. |

### 9.2 Provider Management

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-PRV-1 Provider CRUD` | Partial | Dedicated list/detail/editor flows exist; safe delete with fallback and undo restore are wired through the notifier. | The destructive path that reassigns conversations and soft-deletes the provider is still two sequential repository writes rather than one explicit SQLite transaction boundary. |
| `FR-PRV-2 Provider Configuration Form` | Complete | The shared provider editor renders fields from `ProviderConfigurationSchemas`, validates headers and URLs, and supports duplicate-key prevention plus shared rendering for both provider types. | No material gap. |
| `FR-PRV-3 Provider Health Check` | Complete | Health checks refresh opportunistically on app start with a five-minute cache; save and manual refresh flow through the shared editor and management sheet. | No material gap. |
| `FR-PRV-4 Default Model Selection` | Complete | Default model selection exists in the shared editor; models can be fetched on demand; stale selections refresh before save; new conversations inherit the provider default. | No material gap. |
| `FR-PRV-5 Custom Ollama Endpoint` | Partial | Manual Ollama endpoint entry and discovery-based candidate selection exist; provider cards classify endpoints as local/LAN/remote. | Save is still not hard-gated on a successful probe of a custom endpoint. |
| `FR-PRV-6 Provider Parameters` | Complete | The shared editor exposes `temperature`, `max_tokens`, and `top_p`, validates numeric ranges, and supports reset-to-defaults; adapters apply saved settings to outbound requests. | No material gap. |

### 9.3 Chat Interface

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-CHT-1 Send / Receive Messages` | Complete | The composer auto-resizes; send is disabled for empty or whitespace-only input; double-submit protection exists; user messages are stored before streaming; Enter submits; focus returns to composer after send/new-conversation. | No material gap. |
| `FR-CHT-2 Streaming Responses` | Partial | Assistant messages stream incrementally; provider chunk formats are normalized; completion/cancellation/failure states are distinct. | The UI update cadence is not configurable to the spec target, and there is no explicit long-output performance test coverage. |
| `FR-CHT-3 Markdown Rendering` | Partial | Messages render through `MarkdownBody` with a controlled style sheet. `CodeBlockBuilder` provides syntax highlighting via `flutter_highlight`. | No explicit HTML sanitization/constrained fallback layer exists, and there is no custom rendering for tables, links, or advanced Markdown states. |
| `FR-CHT-4 Code Block Highlighting` | Complete | `CodeBlockBuilder` detects fenced code blocks and language hints, provides per-block copy button, and renders via `flutter_highlight`. `show_code_line_numbers` is stored in app settings. | No material gap. |
| `FR-CHT-5 New Conversation` | Complete | Users can start a fresh thread from the conversation rail button or via `Ctrl/Cmd+N`; focus returns to the input field after creation. | No material gap. |
| `FR-CHT-6 Stop Generation` | Complete | Stop is exposed in the composer; cancellation calls through the notifier and service; partial content remains stored. | No material gap. |
| `FR-CHT-7 Edit Message` | Complete | Users may edit a prior user message; editing creates a new active generation branch by superseding the original and all subsequent messages; the new branch streams into a fresh assistant placeholder. `MessageStatus.superseded` was added to the schema via migration `003`. | No material gap. |

### 9.4 Conversation Management

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-CNV-1 Conversation List` | Partial | Pinned-first sorting and pagination APIs exist; the UI supports pin/archive/delete with undo, rename, search, export, and pull-to-refresh. | The UI does not actually use paginated/incremental loading, and there is no performance verification for `1000+` conversations. |
| `FR-CNV-2 Persistent History` | Partial | Conversation/message persistence is SQLite-backed across restarts; foreign keys are enabled. | Not all write paths are explicitly transaction-safe at the application level, and crash-recovery/integrity checks are missing. |
| `FR-CNV-3 Delete Conversation` | Partial | Deletion is soft delete using `deleted_at`; a SnackBar with Undo is shown immediately; `purgeOldDeleted` DAO method exists for future retention enforcement. | There is no explicit 30-day retention scheduler running the purge. |
| `FR-CNV-4 Rename Conversation` | Complete | DAO/repository support title updates; a rename dialog is available from the conversation tile popup menu. | No material gap. |
| `FR-CNV-5 Search History` | Partial | Basic title `LIKE` search is implemented in the conversation rail with debounced input. | No unified search feature, no FTS5, no message-content search, no snippets, and no highlighting. |
| `FR-CNV-6 Export Chat` | Complete | `ExportService` supports Markdown and JSON export; a share sheet is shown from the conversation tile; filename patterns are deterministic and human-readable; JSON contains metadata and active branch only. | PDF export is not implemented. |

### 9.5 Provider Switching

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-SWT-1 Provider Selector` | Partial | The chat header exposes a provider dropdown and a model dropdown populated from cached models; conversation provider/model selection is persisted. | There is no search in the selector and no unavailable-provider expansion state. |
| `FR-SWT-2 Quick Model Shortcuts` | Complete | Up to 3 most recently used models are surfaced as `ActionChip`s below the provider/model selectors; tapping a chip updates the conversation-level selected model. | No material gap. |
| `FR-SWT-3 Provider Indicator` | Complete | The chat header shows provider name and model context, and the provider control is interactive. | No material gap. |
| `FR-SWT-4 Switch Mid-Chat` | Partial | Users can change provider/model before sending the next turn via the header dropdowns; conversation text history is reused. | There is no visible system divider marking the switch in the transcript. |

### 9.6 Cost Tracking

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-CST-1 Token Counting` | Partial | Provider-reported usage is preferred; fallback estimation uses a character heuristic; per-message usage is stored. | The fallback is not tokenizer-based, and there is no explicit `estimated` flag on message records. |
| `FR-CST-2 Usage Dashboard` | Partial | Daily/weekly/monthly aggregation, local vs cloud split, and provider breakdown exist; the sheet UI exists. | No "money saved" metric, no charting, and no reconciliation tests exist. |
| `FR-CST-3 Spending Alerts` | Partial | Monthly threshold persistence and single-crossing banner state exist; the in-app banner is shown. | No local notification dispatch exists, and the app does not suggest local alternatives after alerting. |

### 9.7 Platform And Offline

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-PLT-1 Responsive Layout` | Complete | Mobile drawer layout and desktop split-pane layout are implemented with deterministic breakpoints. | No material gap. |
| `FR-PLT-2 Offline Support` | Partial | Remote sends queue while offline; outbox backoff/polling exists; queued state is visible in message status labels; a global `ConnectivityBanner` shows online/offline state. | There is no queued-job manual retry UI and no explicit connectivity-restoration trigger beyond the banner. |
| `FR-PLT-3 Keyboard Shortcuts` | Complete | Desktop shortcuts for new chat (`Ctrl/Cmd+N`), send (`Ctrl/Cmd+Enter`), and stop (`Escape`) are registered via `CallbackShortcuts` in `ChatWorkspace`. | No material gap. |

## 10. User Interface Specification

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `10.1 App Shell` | Partial | Onboarding, conversation list, chat detail, provider management, settings, and usage dashboard now exist across `lib/features/`. | Settings is basic; no notification center. |
| `10.2 Navigation Model` | Partial | Mobile uses a drawer, desktop uses persistent list + detail, usage/settings are shown as modal sheets or pushed routes, and provider management/editor/delete confirmation flows exist as modals. | No archive recovery UI. |
| `10.3 Conversation Title Rules` | Partial | Titles derive from the first user message; explicit rename is now supported via dialog. | There is no manual-title vs auto-title tracking, and no later auto-title suppression after rename. |
| `10.4 Status UI States` | Partial | Message states are shown; first-run/loading/empty-state flows exist; provider health state is surfaced; global offline banner is rendered. | Syncing state is not rendered explicitly. |

## 11. Non-Functional Requirements

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `11.1 Performance` | Partial | DB indexes and throttled streaming writes exist; `ListView.separated` is used for messages and conversations. | No measured targets, no large-transcript profiling, and no paginated message/conversation UI usage. |
| `11.2 Reliability` | Partial | Messages are persisted before transport; failures surface as `failed`, `queued`, or `cancelled` states. | No integrity checks, no crash-recovery tooling, and no end-to-end reliability tests exist. |
| `11.3 Security` | Partial | Secure storage is used for the dedicated API-key field; exports exclude secrets. | Remote HTTPS/TLS is not enforced for non-local endpoints; no insecure-local-development opt-in flow; no log/header redaction layer exists; custom-header secrets can still be persisted in SQLite and outbox payloads. |
| `11.4 Accessibility` | Partial | The app uses standard Material controls and mostly text-labeled states. | There is no explicit accessibility audit, no dedicated semantics work, and no test coverage for screen readers/touch targets. |
| `11.5 Observability` | Not | No logging/telemetry module exists in `lib/`. | No structured categories, no debug request tracing, and no stream lifecycle tracing exist. |

## 12. Testing Strategy

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `12.1 Unit Tests` | Partial | `test/unit/message_test.dart` tests message entity behavior; `test/unit/export_service_test.dart` tests Markdown/JSON export formatting. | No repository, adapter, validation, usage, or retry unit tests exist. |
| `12.2 Widget Tests` | Partial | `test/widget_test.dart` verifies `FossChatApp` builds inside `ProviderScope`. | No onboarding, provider form, conversation list, chat composer, or Markdown rendering widget tests exist. |
| `12.3 Integration Tests` | Not | No integration test directory or flows exist. | Entire section is missing. |
| `12.4 Manual Test Matrix` | Not | No manual test matrix or QA checklist exists in the repo. | Entire section is missing. |

## 13. Delivery Plan And Phase Gates

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `13.1 Phase 0: Foundation` | Partial | Flutter bootstrap, shell, database bootstrap, and basic tests exist. | Logging and environment/config scaffolding are missing. |
| `13.2 Phase 1: Core Persistence And Provider Setup` | Partial | Onboarding, local-only completion, secure API-key handling, shared schema-driven provider forms, provider CRUD UI, health checks, and default model selection are implemented. | Repository-level transaction hardening for provider deletion/fallback flows is still incomplete. |
| `13.3 Phase 2: Core Chat` | Partial | Conversation creation, send/stream/stop, adapters, persistence, code highlighting, edit branching, and keyboard shortcuts exist. | Better retry UX and stronger reliability/testing are missing. |
| `13.4 Phase 3: Conversation Operations` | Partial | Conversation list, pin/archive/delete with undo, rename, search, export, and provider selector baseline exist. | Pagination, FTS5 search, and archive recovery are missing. |
| `13.5 Phase 4: Responsive And Offline Behavior` | Partial | Responsive split-pane, outbox polling baseline, offline banner, and keyboard shortcuts exist. | Queued-job manual retry UI and platform-specific connectivity handling are incomplete. |
| `13.6 Phase 5: Expansion Features` | Partial | Provider parameters, usage dashboard/thresholds, edit branching, search, export, keyboard shortcuts, and recent-model shortcuts are implemented. | Stricter custom-Ollama endpoint gating, provider-switch dividers, and FTS5 search are missing. |
| `13.7 Phase 6: Usage And Alerts` | Partial | Usage aggregation and in-app threshold banners exist. | Notifications, alert suggestions, and test reconciliation are missing. |

## 14. Critical Path

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `14. Critical Path` | Partial | Platform bootstrap, network permissions/entitlements, DB layer, secure storage, provider adapters, provider management, conversation persistence, send/stream/stop, code highlighting, edit branching, responsive shell, offline banner, and basic tests are present. | Offline queue manual retry, conversation pagination, integration tests, and local notification readiness are still incomplete. |

## 15. Risk Register

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `15.1 Provider API Variance` | Partial | Variance is normalized through adapter classes. | No provider-specific regression tests exist, and OpenAI-compatible NDJSON fallback is missing. |
| `15.2 Background Work On Desktop` | Partial | The code treats foreground polling as the baseline. | There is no explicit desktop-specific lifecycle/connectivity integration beyond timers. |
| `15.3 History Branching Complexity` | Partial | `generation_group_id` and `edited_from_message_id` are in the schema/entity; `MessageStatus.superseded` was added via migration `003`; edit branching UX is implemented. | No material gap in the baseline branching feature. |
| `15.4 Large Transcript Performance` | Partial | Message persistence is throttled, and the UI uses `ListView.separated`. | There is no pagination in the chat UI, and no performance tests for large transcripts. |
| `15.5 Secret Handling Regressions` | Not | No redaction utility or redaction tests exist. | The mitigation named in the spec is unimplemented. |

## 16. Estimated Delivery Effort

| Feature Domain | Estimated Effort |
| --- | --- |
| Onboarding and setup | 6.0 developer days |
| Provider management | 10.0 developer days |
| Chat interface | 10.0 developer days |
| Conversation management | 8.5 developer days |
| Provider switching | 5.0 developer days |
| Cost tracking | 6.0 developer days |
| Platform and offline | 6.5 developer days |
| Total implementation scope | 52.0 developer days |

- Baseline Release: approximately 33.5 developer days
- Expansion Release: approximately 18.5 additional developer days
- Full implementation scope: approximately 52 developer days before contingency

Recommended planning buffer:
- add 20 to 30 percent contingency for cross-platform issues, streaming edge cases, and provider variance

## 17. Feature Coverage Matrix

| Feature Domain | Implementation Sections |
| --- | --- |
| Onboarding & Setup | FR-ONB-1 to FR-ONB-4, Phases 1-2 |
| Provider Management | FR-PRV-1 to FR-PRV-6, Phases 1 and 5 |
| Chat Interface | FR-CHT-1 to FR-CHT-7, Phases 2 and 5 |
| Conversation Management | FR-CNV-1 to FR-CNV-6, Phases 2, 3, and 5 |
| Provider Switching | FR-SWT-1 to FR-SWT-4, Phases 3 and 5 |
| Cost Tracking | FR-CST-1 to FR-CST-3, Phase 6 |
| Platform & Offline | FR-PLT-1 to FR-PLT-3, Phases 4 and 5 |

## 18. Implementation Start Checklist

Before coding begins, the team should confirm:

- the supported provider list for Release 1
- whether macOS background jobs are in or out of scope for the first release
- whether export and search are core-release candidates or explicitly deferred
- whether edit-message branching is required in the first shipped build
- the exact breakpoint policy for phone, tablet, and desktop layouts

Once those are confirmed, implementation can start from Phase 0.

## Prioritized TODO List

1. **Close remaining secret-handling gaps.**
   Treat `Authorization`/`api-key` style headers as secrets, keep them out of SQLite and `outbox_jobs.payload_json`, add masking/redaction for secret-like header values, and enforce the spec's TLS vs local-development policy.

2. **Finish conversation pagination and large-list performance.**
   Wire `getPaginated` to the conversation list UI with incremental loading and verify performance with large conversation counts.

3. **Implement provider/model switch dividers in the transcript (FR-SWT-4).**
   Insert a visible system message or divider widget when the user changes provider or model mid-chat.

4. **Upgrade search to FTS5.**
   Add an FTS5 virtual table for conversation titles and message content; implement debounced search with snippets and highlighting.

5. **Add observability and structured logging.**
   Introduce structured logging categories (database, providers, streaming, sync, ui), debug-only request tracing with secret redaction, and stream lifecycle events.

6. **Schedule retention purge.**
   Run `ConversationDao.purgeOldDeleted` on a periodic basis (e.g., on app launch) with a 30-day threshold.

7. **Build the test suite the spec expects.**
   Add repository/migration tests, adapter normalization tests, onboarding/provider/chat widget tests, and at least one streamed chat integration test with offline-queue retry coverage.

8. **Wire up local notifications for spending alerts.**
   Initialize `flutter_local_notifications` and dispatch a local notification when the monthly threshold is exceeded.
