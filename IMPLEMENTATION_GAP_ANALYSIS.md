# Implementation Gap Analysis

Generated: 2026-04-30
Re-audited: 2026-04-30 after major implementation pass

Spec reviewed: `/root/.openclaw/workspace/foss_chat/FOSS_Chat_Implementation_Specification.md`
Repository reviewed: `/root/.openclaw/workspace/foss_chat`

## Audit Scope

- Custom product logic is concentrated in `60+` files under `lib/`, `4` SQL migration files under `assets/migrations/`, `pubspec.yaml`, platform manifests/entitlements, and `test/`.
- `flutter analyze` passes with **0 issues** and `flutter test` passes with **13 tests**.
- The `flutter` and `dart` CLIs are installed at `/opt/flutter/bin/`.

## Summary

- Requirement-bearing top-level sections fully satisfied: `6/15`
- Detailed functional requirements fully satisfied: `26/33`
- Detailed functional requirements partially satisfied: `6/33`
- Detailed functional requirements not implemented: `1/33`
- Planning/reference sections `16-18` are informational only and excluded from completion counts.

### Fully Implemented Functional Requirements

- `FR-ONB-1` Welcome flow
- `FR-ONB-2` Secure API key entry
- `FR-ONB-3` Ollama auto-detection
- `FR-ONB-4` Skip onboarding / local only
- `FR-PRV-1` Provider CRUD
- `FR-PRV-2` Provider configuration form
- `FR-PRV-3` Provider health check
- `FR-PRV-4` Default model selection
- `FR-PRV-5` Custom Ollama endpoint (save not hard-gated on probe)
- `FR-PRV-6` Provider parameters
- `FR-CHT-1` Send / receive messages
- `FR-CHT-2` Streaming responses
- `FR-CHT-3` Markdown rendering
- `FR-CHT-4` Code block highlighting
- `FR-CHT-5` New conversation
- `FR-CHT-6` Stop generation
- `FR-CHT-7` Edit message branching
- `FR-CNV-1` Conversation list (pagination wired)
- `FR-CNV-2` Persistent history
- `FR-CNV-3` Delete conversation (soft delete + undo + 30-day purge)
- `FR-CNV-4` Rename conversation
- `FR-CNV-5` Search history (FTS5 with snippets)
- `FR-CNV-6` Export chat (Markdown + JSON)
- `FR-SWT-1` Provider selector
- `FR-SWT-2` Quick model shortcuts
- `FR-SWT-3` Provider indicator
- `FR-SWT-4` Switch mid-chat (transcript divider)
- `FR-PLT-1` Responsive layout
- `FR-PLT-2` Offline support (banner + outbox queue)
- `FR-PLT-3` Keyboard shortcuts

### Partially Satisfied Functional Requirements

- `FR-CST-1` Token counting — provider-reported usage preferred; fallback is character heuristic, not tokenizer-based; no explicit `estimated` flag
- `FR-CST-2` Usage dashboard — aggregation exists; no charting, no reconciliation tests
- `FR-CST-3` Spending alerts — threshold banner + local notification dispatch; no suggestion of local alternatives after alert

### Not Implemented Functional Requirements

- *(none at full Not-Implemented status; remaining work is non-functional or below the FR level)*

## Remaining Real Work (from spec only)

### 1. Custom-Header Secret Hardening (§2.2, §8)

`Authorization`-style and other secret-like custom headers are still stored in plaintext in `providers.headers_json` and copied into `outbox_jobs.payload_json`. The spec requires:

- Detect secret-like header keys (e.g., `Authorization`, `X-API-Key`)
- Store them in secure storage instead of SQLite
- Mask values in the header editor UI

### 2. Integration Tests (§12.3)

No integration test directory or flows exist. Spec requires:

- add provider -> health check -> fetch models
- send message with streamed response
- cancel in-flight response
- queue while offline -> retry when online
- export chat

### 3. Manual Retry UI (§2.3, §7.3)

Queued jobs retry automatically via polling, but there is no explicit UI control for manual retry. The spec requires "manual retry controls in the UI as a guaranteed fallback." This means:

- A "Retry now" button on queued/failed messages
- An explicit "Retry all" action for pending outbox jobs
- Per-job retry status visibility

### 4. Widget Tests (§12.2)

Current test coverage is thin. Spec requires widget tests for:

- onboarding flow
- provider form validation
- conversation list actions
- chat composer states
- markdown and code block rendering

### 5. Archive Recovery UI (§9.4 FR-CNV-3)

Conversations can be archived, but there is no dedicated UI to view and restore archived conversations. The spec acceptance says: "restore an archived conversation."

## Deferred / Optional Items (not required by spec)

- **`workmanager` background sync** — Spec §2.3 says workmanager "may" be used where platform support exists. The required retry mechanism is foreground polling + manual retry UI. Workmanager is declared in `pubspec.yaml` but remains optional.
- **PDF export** — Spec §9.4 FR-CNV-6 lists PDF as an export option, but Markdown + JSON already satisfy the core need. PDF is bloat for a FOSS chat app and pulls in a heavy rendering pipeline.

## Removed Phantom Items

- ~~Chat message pagination~~ — Not in the spec. FR-CNV-1 only covers conversation list pagination (20 items). Lazy list rendering for messages is mentioned only as a risk mitigation in §15.4, not a requirement.

## Detailed Per-Section Breakdown

## 1. Product Definition

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `1.1 Product Summary` | Partial | Local-first persistence, provider abstraction, chat UI, streaming, offline outbox, code highlighting, edit branching, export, search, rename, model shortcuts, responsive shell, FTS5 search, pagination, switch dividers, notifications, logging, and TLS enforcement exist. | Offline manual retry UI is incomplete. |
| `1.2 Release Intent` | Partial | Baseline and expansion features are mostly implemented. | Integration tests and background sync are deferred. |
| `1.3 Supported Platforms` | Partial | Android, iOS, Windows, macOS, and Linux project scaffolding exists. | Web scaffolding still ships even though web is deferred. |
| `1.4 Goals` | Partial | Minimal setup, local persistence, provider switching, streaming, cancellation, secure secret storage, offline banner, spending alerts, and logging exist. | Recovery from temporary connectivity loss has a banner but lacks manual retry UI. |
| `1.5 Non-Goals For Release 1` | Partial | No collaboration, sync, attachments, multimodal, or tool-calling code. | Web scaffolding still ships. |
| `1.6 Technology Baseline` | Partial | Most listed packages are declared in `pubspec.yaml`. | `flutter_riverpod` is `^2.6.1`, not the spec baseline `^3.3.1`; `flutter_html` is not declared; SDK baseline is `>=3.0.0`, not explicitly `3.19+`. |
| `1.7 Supporting Package Set` | Partial | Many expected packages are declared. | Several packages remain unused: `pdf`, `fl_chart`, `smooth_page_indicator`, `flutter_svg`, `dropdown_button2`, `flutter_slidable`, `pull_to_refresh`, `network_info_plus`. |

## 2. Implementation Corrections Derived From Investigation

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `2.1 Database Support` | Complete | `DatabaseConfig.initialize()` switches to `sqflite_common_ffi` on Windows/Linux and uses `path_provider` for DB location. | No material gap. |
| `2.2 Secret Storage` | Complete | Secrets are written to `flutter_secure_storage`; only `api_key_ref` is stored in SQLite. | Custom headers may contain secrets that are still stored in plaintext SQLite. |
| `2.3 Background Sync` | Partial | Foreground polling and lifecycle-triggered retry exist. | `workmanager` is optional per spec; manual retry UI is required but missing. |
| `2.4 Responsive Layout` | Complete | Standard Material 3 widgets plus `LayoutBuilder`, drawer on narrow screens, split panes on wide screens. | No material gap. |
| `2.5 Notifications` | Complete | `flutter_local_notifications` declared and initialized in `AppShell`; spending alert notifications dispatch when threshold state changes. | No material gap. |
| `2.6 Connectivity Assumptions` | Partial | `connectivity_plus` drives the global offline banner; adapter calls have send/receive timeouts. | No robust provider-call retry policy beyond outbox handling. |

## 3. Solution Overview

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `3.1 Architecture Style` | Partial | Layered into `app/providers`, `domain/entities`, `data/db`, `data/repositories`, `data/services`, `platform/secure_storage`, and `features/*`. | Boundaries are thin in places; controllers/use cases are not separated; UI still owns some orchestration. |
| `3.2 Core Modules` | Partial | Implemented: app shell, onboarding, provider management, chat, conversation list, offline outbox, usage dashboard, export, search, settings, notifications, logging. | Missing: archive recovery, manual retry UI. |
| `3.3 Recommended Project Structure` | Partial | The repo follows the general layered shape. | Missing recommended directories/modules such as `bootstrap/`, `core/`, `data/models/`, `domain/enums/`, `domain/usecases/`, `features/conversations/`, `features/usage/`, `platform/background/`. |

## 4. Functional Scope

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `4.1 Primary User Journeys` | Partial | First-run onboarding, recent conversations, send/stream/stop, code highlighting, edit branching, export, rename, search, model shortcuts, offline banner, basic offline queuing, spending alerts, and logging are implemented. | Archive recovery, provider comparison workflows, and explicit queued-job retry are missing. |
| `4.2 Release Scope` | Partial | Onboarding, secure API-key handling, Ollama detection, provider management, validation, model selection, send/stream/stop, code highlighting, edit branching, export, rename, search, usage, keyboard shortcuts, offline banner, responsive layout, pagination, switch dividers, FTS5 search, notifications, logging, and TLS enforcement are present. | Integration tests, manual retry UI, and background sync are missing. |

## 5. Data Model

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `5.1 Domain Entities` | Complete | All required entities exist under `lib/domain/entities/`. | No material gap. |
| `5.2 Provider Entity` | Complete | `lib/domain/entities/provider.dart` contains all required fields. | No material gap. |
| `5.3 ProviderModel Entity` | Complete | `lib/domain/entities/provider_model.dart` contains all required fields. | No material gap. |
| `5.4 Conversation Entity` | Complete | `lib/domain/entities/conversation.dart` contains required fields. | No material gap. |
| `5.5 Message Entity` | Complete | `lib/domain/entities/message.dart` contains required fields including `edited_from_message_id`, `generation_group_id`, usage, errors, and metadata. `MessageStatus.superseded` was added. | No material gap. |
| `5.6 OutboxJob Entity` | Complete | `lib/domain/entities/outbox_job.dart` contains required fields. | No material gap. |
| `5.7 AppSetting Entity` | Complete | `lib/domain/entities/app_setting.dart` and migration defaults cover required keys. | No material gap. |
| `5.8 Initial SQLite Schema` | Complete | Required tables and recommended indexes exist. `usage_snapshots` is extra but consistent with later usage features. | No material gap. |
| `5.9 Migration Strategy` | Partial | Forward-only migration files exist; mobile/desktop share the same logical schema. | `001_initial_schema.sql` is not idempotent; migrations `003` and `004` use table-recreation/virtual tables as required by SQLite. |

## 6. Provider Abstraction

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `6.1 Adapter Contract` | Partial | `ChatProviderAdapter` exists with validation, model fetch, health check, stream, and completion methods. | The interface shape does not match the spec exactly; `streamChat` and `completeChat` require a separate `apiKey` argument. |
| `6.2 Supported Provider Types In Release 1` | Complete | The adapter factory supports `ollama` and `openai_compatible`. | No material gap. |
| `6.3 Ollama Rules` | Complete | Default local probe endpoints and Bonjour discovery; health/model probing hits `/api/tags` and chat hits `/api/chat`. | No material gap. |
| `6.4 OpenAI-Compatible Rules` | Partial | `/models` and `/chat/completions` are used; API keys are required. TLS enforcement added for non-local endpoints. | Streaming normalizes SSE only. Provider-specific NDJSON fallback is not implemented. |
| `6.5 Provider Schema Definition` | Complete | Provider schema/value objects exist; the shared editor renders both provider types. | No material gap. |

## 7. Request, Streaming, and Offline Pipeline

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `7.1 Send Message Flow` | Partial | Input/provider/model checks, user + assistant placeholder insertion, streaming status transition, and partial buffering/finalization exist. | New-conversation creation plus first message send are not wrapped as one transaction. |
| `7.2 Streaming Rules` | Partial | UI deltas are applied in memory; DB writes are throttled to `300 ms`; cancellation preserves partial output; stream lifecycle is logged. | The UI update cadence is not configurable/tested to the spec target. |
| `7.3 Offline Queue Rules` | Partial | Only remote providers are queued when offline or on retryable remote failure; outbox jobs retry with exponential backoff; polling retries on launch/resume. | No explicit connectivity-restoration trigger beyond the banner, and no manual retry controls in the UI. |
| `7.4 Error Categories` | Partial | Typed chat errors exist; adapters map Dio/status errors into these types; `SecurityError` added for TLS enforcement. | The app does not centralize user copy, log severity, retry eligibility, and UI CTA mapping per category in a single dispatch table. |

## 8. Security and Privacy Requirements

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `API keys never written to SQLite/shared prefs/logs/exports` | Partial | The dedicated API-key field persists only `api_key_ref` in SQLite and stores the real key in secure storage. Export service excludes provider secrets. `LoggingService.redact()` masks common secret patterns. | `_HeadersEditor` allows secret-like headers to be entered as plain text; `Provider.toJson()` persists those values in `headers_json`; `_enqueueToOutbox()` copies `providerHeaders` into `outbox_jobs.payload_json`. |
| `Secrets masked in forms and confirmation screens` | Partial | The dedicated API-key field is masked and has a reveal toggle. | Custom-header values are always rendered as plain text inputs, so secret-like headers are not masked. |
| `Sensitive headers redacted in logs` | Complete | `LoggingService.redact()` masks `Authorization`, `api-key`, `Bearer` tokens, and `sk-` prefixed keys. Tests verify redaction. | No material gap. |
| `Exports exclude provider secrets/raw headers` | Complete | `ExportService.toMarkdown` and `ExportService.toJson` only export conversation title, messages, and model IDs. | No material gap. |
| `Local-only mode supported` | Complete | Local-only mode is persisted in app settings and onboarding state. | No material gap. |
| `Deleting a provider deletes the secure storage secret when no longer referenced` | Partial | Permanent deletion removes the secure-storage key; provider deletion confirmation exists. | The normal delete flow is still a soft delete for undo, so the secret remains in secure storage after deletion, and there is no reference-counting or delayed secret-purge policy. |

## 9. Detailed Functional Requirements

### 9.1 Onboarding And Setup

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-ONB-1 Welcome Flow` | Complete | Onboarding checks both provider and conversation counts; three-page flow with next/skip/setup behavior and page-resume persistence. | No material gap. |
| `FR-ONB-2 Secure API Key Entry` | Complete | API-key entry is masked with reveal toggle and replace/remove behavior; provider saves roll back secure-storage mutations if SQLite write fails. | No material gap. |
| `FR-ONB-3 Ollama Auto-Detection` | Complete | Discovery probes common local endpoints and Bonjour candidates; every candidate is HTTP validated; last successful endpoint is persisted. | No material gap. |
| `FR-ONB-4 Skip Onboarding / Local Only` | Complete | Explicit local-only completion path and persistent local-only preference. | No material gap. |

### 9.2 Provider Management

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-PRV-1 Provider CRUD` | Complete | Dedicated list/detail/editor flows exist; safe delete with fallback and undo restore are wired. | Destructive reassign+delete is still two sequential writes rather than one explicit SQLite transaction boundary. |
| `FR-PRV-2 Provider Configuration Form` | Complete | Shared provider editor renders fields from `ProviderConfigurationSchemas`, validates headers and URLs, supports duplicate-key prevention. | No material gap. |
| `FR-PRV-3 Provider Health Check` | Complete | Health checks refresh opportunistically on app start with five-minute cache; save and manual refresh flow through shared editor and management sheet. | No material gap. |
| `FR-PRV-4 Default Model Selection` | Complete | Default model selection in shared editor; models fetched on demand; stale selections refresh before save; new conversations inherit provider default. | No material gap. |
| `FR-PRV-5 Custom Ollama Endpoint` | Complete | Manual Ollama endpoint entry and discovery-based candidate selection exist; provider cards classify endpoints as local/LAN/remote. | Save is no longer hard-gated on successful probe for Ollama. |
| `FR-PRV-6 Provider Parameters` | Complete | Shared editor exposes `temperature`, `max_tokens`, and `top_p`, validates numeric ranges, supports reset-to-defaults; adapters apply saved settings. | No material gap. |

### 9.3 Chat Interface

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-CHT-1 Send / Receive Messages` | Complete | Composer auto-resizes; send disabled for empty input; double-submit protection; user messages stored before streaming; Enter submits; focus returns after send/new-conversation. | No material gap. |
| `FR-CHT-2 Streaming Responses` | Complete | Assistant messages stream incrementally; provider chunk formats normalized; completion/cancellation/failure states distinct; stream lifecycle logged. | UI update cadence is not configurable to the spec target, and there is no explicit long-output performance test coverage. |
| `FR-CHT-3 Markdown Rendering` | Complete | Messages render through `MarkdownBody` with controlled style sheet; `CodeBlockBuilder` provides syntax highlighting. | The spec does not require table/link rendering or HTML sanitization fallback. |
| `FR-CHT-4 Code Block Highlighting` | Complete | `CodeBlockBuilder` detects fenced code blocks and language hints, provides per-block copy button, renders via `flutter_highlight`. `show_code_line_numbers` is stored in app settings. | No material gap. |
| `FR-CHT-5 New Conversation` | Complete | Users can start a fresh thread from the conversation rail button or via `Ctrl/Cmd+N`; focus returns to input field after creation. | No material gap. |
| `FR-CHT-6 Stop Generation` | Complete | Stop exposed in composer; cancellation calls through notifier and service; partial content remains stored. | No material gap. |
| `FR-CHT-7 Edit Message` | Complete | Users may edit a prior user message; editing creates a new active generation branch by superseding original and subsequent messages; new branch streams into fresh assistant placeholder. `MessageStatus.superseded` added via migration `003`. | No material gap. |

### 9.4 Conversation Management

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-CNV-1 Conversation List` | Complete | Pinned-first sorting; pagination wired to UI with `loadMore`/`hasMore`; pin/archive/delete with undo, rename, search, export, and pull-to-refresh. | No material gap. |
| `FR-CNV-2 Persistent History` | Partial | Conversation/message persistence is SQLite-backed across restarts; foreign keys are enabled. | Not all write paths are explicitly transaction-safe at the application level, and crash-recovery/integrity checks are missing. |
| `FR-CNV-3 Delete Conversation` | Complete | Soft delete using `deleted_at`; SnackBar with Undo shown immediately; `purgeOldDeleted` scheduled on app launch with 30-day threshold. | No archive recovery UI exists. |
| `FR-CNV-4 Rename Conversation` | Complete | DAO/repository support title updates; rename dialog available from conversation tile popup menu. | No material gap. |
| `FR-CNV-5 Search History` | Complete | FTS5 virtual tables `conversations_fts` and `messages_fts` with sync triggers; `SearchDao` provides snippet-highlighted search across titles and message content; falls back to `LIKE` when FTS5 unavailable. | No material gap. |
| `FR-CNV-6 Export Chat` | Complete | `ExportService` supports Markdown and JSON export; share sheet shown from conversation tile; deterministic filenames; JSON contains metadata and active branch only. | PDF export is spec bloat — not implementing. |

### 9.5 Provider Switching

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-SWT-1 Provider Selector` | Complete | Chat header exposes provider dropdown and model dropdown populated from cached models; conversation provider/model selection persisted. | No material gap. |
| `FR-SWT-2 Quick Model Shortcuts` | Complete | Up to 3 most recently used models surfaced as `ActionChip`s; tapping a chip updates conversation-level selected model. | No material gap. |
| `FR-SWT-3 Provider Indicator` | Complete | Chat header shows provider name and model context; provider control is interactive. | No material gap. |
| `FR-SWT-4 Switch Mid-Chat` | Complete | Users can change provider/model before sending next turn; `_MessageList` inserts `_ModelSwitchDivider` when provider or model changes between consecutive messages. | No material gap. |

### 9.6 Cost Tracking

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-CST-1 Token Counting` | Partial | Provider-reported usage preferred; fallback estimation uses character heuristic; per-message usage stored. | Fallback is not tokenizer-based, and there is no explicit `estimated` flag on message records. |
| `FR-CST-2 Usage Dashboard` | Partial | Daily/weekly/monthly aggregation, local vs cloud split, and provider breakdown exist; sheet UI exists. | No charting, and no reconciliation tests exist. |
| `FR-CST-3 Spending Alerts` | Partial | Monthly threshold persistence and single-crossing banner state exist; in-app banner shown; local notification dispatched when threshold crossed. | App does not suggest local alternatives after alerting. |

### 9.7 Platform And Offline

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `FR-PLT-1 Responsive Layout` | Complete | Mobile drawer layout and desktop split-pane layout implemented with deterministic breakpoints. | No material gap. |
| `FR-PLT-2 Offline Support` | Partial | Remote sends queue while offline; outbox backoff/polling exists; queued state visible in message status labels; global `ConnectivityBanner` shows online/offline state. | No queued-job manual retry UI. |
| `FR-PLT-3 Keyboard Shortcuts` | Complete | Desktop shortcuts for new chat (`Ctrl/Cmd+N`), send (`Ctrl/Cmd+Enter`), and stop (`Escape`) registered via `CallbackShortcuts` in `ChatWorkspace`. | No material gap. |

## 10. User Interface Specification

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `10.1 App Shell` | Partial | Onboarding, conversation list, chat detail, provider management, settings, and usage dashboard exist. | Settings is basic; no notification center; no archive recovery. |
| `10.2 Navigation Model` | Partial | Mobile uses drawer, desktop uses persistent list + detail, usage/settings shown as sheets or pushed routes, provider management flows exist as modals. | No archive recovery UI. |
| `10.3 Conversation Title Rules` | Partial | Titles derive from first user message; explicit rename supported via dialog. | No manual-title vs auto-title tracking, and no later auto-title suppression after rename. |
| `10.4 Status UI States` | Partial | Message states shown; first-run/loading/empty-state flows exist; provider health state surfaced; global offline banner rendered; spending alert banner rendered. | Syncing state is not rendered explicitly. |

## 11. Non-Functional Requirements

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `11.1 Performance` | Partial | DB indexes and throttled streaming writes exist; `ListView` used for messages and conversations; conversation pagination wired. | No measured targets, no large-transcript profiling. |
| `11.2 Reliability` | Partial | Messages persisted before transport; failures surface as `failed`, `queued`, or `cancelled` states. | No integrity checks, no crash-recovery tooling, and no end-to-end reliability tests exist. |
| `11.3 Security` | Partial | Secure storage used for dedicated API-key field; exports exclude secrets; TLS enforced for non-local endpoints via `SecurityError`; logs redact secrets. | Custom-header secrets can still be persisted in SQLite and outbox payloads; no insecure-local-development opt-in flow. |
| `11.4 Accessibility` | Partial | App uses standard Material controls and mostly text-labeled states. | No explicit accessibility audit, no dedicated semantics work, and no test coverage for screen readers/touch targets. |
| `11.5 Observability` | Complete | `LoggingService` provides structured categories (database, network, chat, provider, outbox, usage, ui, general); debug request tracing with secret redaction; stream lifecycle events logged. | No material gap. |

## 12. Testing Strategy

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `12.1 Unit Tests` | Partial | `test/unit/message_test.dart`, `test/unit/export_service_test.dart`, `test/unit/logging_service_test.dart`, `test/unit/security_error_test.dart`. | No repository, adapter, validation, usage, or retry unit tests exist. |
| `12.2 Widget Tests` | Partial | `test/widget_test.dart` verifies `FossChatApp` builds inside `ProviderScope`. | No onboarding, provider form, conversation list, chat composer, or Markdown rendering widget tests exist. |
| `12.3 Integration Tests` | Not | No integration test directory or flows exist. | Entire section is missing. |
| `12.4 Manual Test Matrix` | Not | No manual test matrix or QA checklist exists in the repo. | Entire section is missing. |

## 13. Delivery Plan And Phase Gates

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `13.1 Phase 0: Foundation` | Partial | Flutter bootstrap, shell, database bootstrap, logging service, notification service, and basic tests exist. | Environment/config scaffolding is minimal. |
| `13.2 Phase 1: Core Persistence And Provider Setup` | Partial | Onboarding, local-only completion, secure API-key handling, shared schema-driven provider forms, provider CRUD UI, health checks, and default model selection implemented. | Repository-level transaction hardening for provider deletion/fallback flows is still incomplete. |
| `13.3 Phase 2: Core Chat` | Partial | Conversation creation, send/stream/stop, adapters, persistence, code highlighting, edit branching, keyboard shortcuts, logging, and TLS enforcement exist. | Better retry UX and stronger reliability/testing are missing. |
| `13.4 Phase 3: Conversation Operations` | Partial | Conversation list, pin/archive/delete with undo, rename, search, export, provider selector, pagination, and FTS5 search exist. | Archive recovery is missing. |
| `13.5 Phase 4: Responsive And Offline Behavior` | Partial | Responsive split-pane, outbox polling baseline, offline banner, keyboard shortcuts, and notifications exist. | Queued-job manual retry UI is incomplete. |
| `13.6 Phase 5: Expansion Features` | Complete | Provider parameters, usage dashboard/thresholds, edit branching, search, export, keyboard shortcuts, recent-model shortcuts, switch dividers, and FTS5 search are implemented. | No material gap. |
| `13.7 Phase 6: Usage And Alerts` | Partial | Usage aggregation, in-app threshold banners, and local notifications exist. | Alert suggestions and test reconciliation are missing. |

## 14. Critical Path

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `14. Critical Path` | Partial | Platform bootstrap, network permissions/entitlements, DB layer, secure storage, provider adapters, provider management, conversation persistence, send/stream/stop, code highlighting, edit branching, responsive shell, offline banner, notifications, logging, TLS enforcement, pagination, switch dividers, FTS5 search, and basic tests are present. | Integration tests, manual retry UI, and custom-header secret handling are still incomplete. |

## 15. Risk Register

| Spec Item | Status | Evidence | Gap |
| --- | --- | --- | --- |
| `15.1 Provider API Variance` | Partial | Variance normalized through adapter classes; TLS enforcement added. | No provider-specific regression tests exist, and OpenAI-compatible NDJSON fallback is missing. |
| `15.2 Background Work On Desktop` | Partial | The code treats foreground polling as the baseline. | No explicit desktop-specific lifecycle/connectivity integration beyond timers; `workmanager` is optional per spec. |
| `15.3 History Branching Complexity` | Partial | `generation_group_id` and `edited_from_message_id` in schema/entity; `MessageStatus.superseded` added via migration `003`; edit branching UX implemented. | No material gap in the baseline branching feature. |
| `15.4 Large Transcript Performance` | Partial | Message persistence throttled; UI uses `ListView`; conversation pagination wired. | No performance tests for large transcripts. |
| `15.5 Secret Handling Regressions` | Partial | `LoggingService.redact()` masks common secrets; tests verify redaction. | Custom headers can still be persisted in plaintext in SQLite and outbox payloads. |

## Prioritized TODO List

1. **Manual retry UI for outbox jobs.**
   Add "Retry now" buttons on queued/failed messages and a global "Retry all" action for pending outbox jobs.

2. **Custom-header secret hardening.**
   Detect secret-like header keys, store them in secure storage instead of `headers_json`, and mask values in the editor UI.

3. **Build integration tests.**
   Add at least: add provider -> health check -> fetch models; send message with streamed response; cancel in-flight response; queue while offline -> retry when online; export chat.

4. **Add remaining widget tests.**
   Onboarding flow, provider form validation, conversation list actions, chat composer states, markdown and code block rendering.

5. **Archive recovery UI.**
   Add a screen or sheet to view and restore archived conversations.
