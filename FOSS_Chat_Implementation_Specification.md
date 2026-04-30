# FOSS Chat Implementation Specification

Document purpose: provide a sequential, implementation-ready specification that a delivery team can build from without having to infer major architecture, data, or execution details.  
Prepared: 2026-04-20

## 1. Product Definition

### 1.1 Product Summary

FOSS Chat is a local-first, multi-provider chat application built with Flutter. The product allows a user to configure cloud and local LLM providers, create and manage conversations, stream responses, preserve history, switch providers per conversation, and continue operating in degraded offline conditions.

The product is privacy-oriented, with local execution through Ollama treated as a first-class path rather than an afterthought. The implementation therefore needs to favor:

- durable local storage
- strong secret handling
- graceful degradation when cloud access is unavailable
- a responsive experience on mobile and desktop

### 1.2 Release Intent

The document assumes two delivery targets:

- Baseline Release: the feature set required for a dependable local-first chat product
- Expansion Release: additional usability, analytics, and advanced editing capabilities that can ship after the baseline is stable

### 1.3 Supported Platforms

Release 1 should target:

- Android
- iOS
- Windows
- macOS
- Linux

Web is deferred from Release 1 because the application depends heavily on local secure storage, SQLite, LAN discovery, and provider endpoints that may fail due to browser CORS and sandbox constraints.

### 1.4 Goals

- Let a user start chatting with either a local Ollama instance or a cloud provider with minimal setup.
- Persist all conversations locally.
- Make provider switching easy and reversible.
- Support token streaming, cancellation, and recovery from temporary connectivity loss.
- Preserve privacy by never storing secrets in plaintext application storage.

### 1.5 Non-Goals For Release 1

- multi-user collaboration
- cloud sync between devices
- attachments, images, audio, or multimodal workflows
- tool calling or agent orchestration
- web-first deployment

### 1.6 Technology Baseline

The following package baseline should be treated as the starting implementation stack for Phase 0. Versions may be raised during project bootstrap if compatibility testing requires it, but the architectural roles should remain consistent.

| Category | Package / Approach | Baseline | Purpose |
| --- | --- | --- | --- |
| Framework | `flutter` | `3.19+` | Cross-platform UI |
| Database | `sqflite` plus `sqflite_common_ffi` | `sqflite ^2.4.1` | Local SQLite storage across mobile and desktop |
| Secure Storage | `flutter_secure_storage` | `^9.2.2` | OS keychain / keystore integration |
| HTTP | `dio` | `^5.7.0` | REST, streaming transport, cancellation |
| State | `flutter_riverpod` | `^3.3.1` | Reactive state management |
| Connectivity | `connectivity_plus` | `^6.0.0` | Online/offline signal detection |
| Background Retry | `workmanager` | `^0.5.2` | Deferred remote sync where platform support exists |

### 1.7 Supporting Package Set

These packages are expected to be used in the first implementation pass, with exact versions selected during Phase 0 dependency validation:

- onboarding and lightweight persistence: `shared_preferences`, `smooth_page_indicator`, `flutter_svg`
- forms and validation: `flutter_form_builder`, `form_builder_validators`
- provider discovery and utilities: `bonsoir`, `network_info_plus`, `path_provider`, `uuid`
- chat rendering: `flutter_markdown`, `flutter_html`, `flutter_highlight`
- list and interaction components: `flutter_slidable`, `dropdown_button2`, `pull_to_refresh`
- export and analytics: `share_plus`, `fl_chart`, `intl`
- desktop controls and notifications: `hotkey_manager`, `flutter_local_notifications`

## 2. Implementation Corrections Derived From Investigation

Several implementation assumptions require clarification before build work starts.

### 2.1 Database Support

`sqflite` alone is not sufficient for the full target platform set. The implementation should use:

- `sqflite` on Android, iOS, and macOS
- `sqflite_common_ffi` on Windows and Linux
- `path_provider` to resolve the database location consistently on every platform

### 2.2 Secret Storage

The implementation should store provider API keys directly in `flutter_secure_storage` rather than adding a custom AES layer in the app. Platform secure storage already delegates encryption and key management to OS facilities, which is safer and simpler than maintaining app-managed encryption keys.

### 2.3 Background Sync

Offline queue processing may use `workmanager` on supported platforms, but it must not be treated as the universal retry mechanism. The implementation should use:

- background tasks where platform support exists
- foreground retry on app launch, resume, and connectivity restoration on desktop
- manual retry controls in the UI as a guaranteed fallback

### 2.4 Responsive Layout

Responsive layout should not rely on `flutter_adaptive_scaffold` as a baseline dependency. The safer implementation path is:

- standard Material 3 widgets
- `LayoutBuilder` and breakpoint utilities
- `NavigationBar`, `NavigationRail`, and split-pane layouts built in-app

This avoids unnecessary risk tied to discontinued or weakly maintained layout packages.

### 2.5 Notifications

For spending alerts and future local notifications, use `flutter_local_notifications` rather than a vague `local_notifications` placeholder.

### 2.6 Connectivity Assumptions

`connectivity_plus` should be used only as a signal, not as proof that requests will succeed. Provider calls must still enforce timeouts, retries, and user-visible error states.

## 3. Solution Overview

### 3.1 Architecture Style

Use a layered Flutter architecture:

- Presentation: widgets, pages, dialogs, app shell, local view models
- Application: Riverpod notifiers, controllers, use cases, orchestration logic
- Domain: entities, value objects, provider capability contracts
- Infrastructure: SQLite repositories, secure storage, HTTP clients, provider adapters, background sync

### 3.2 Core Modules

- app shell and navigation
- onboarding and initial setup
- provider management
- chat composition and streaming
- conversation management
- offline queue and sync
- usage tracking and alerts
- export and search

### 3.3 Recommended Project Structure

```text
lib/
  app/
  bootstrap/
  core/
    constants/
    errors/
    logging/
    utils/
  data/
    db/
      migrations/
      dao/
    models/
    repositories/
    services/
  domain/
    entities/
    enums/
    interfaces/
    usecases/
  features/
    onboarding/
    providers/
    chat/
    conversations/
    usage/
    settings/
  platform/
    background/
    notifications/
    secure_storage/
```

## 4. Functional Scope

### 4.1 Primary User Journeys

1. First launch -> onboarding -> choose local-only or provider setup -> enter provider details -> validate connection -> start first chat.
2. Return user -> open recent conversation or create a new one -> send message -> stream response -> stop, edit, retry, or continue.
3. User loses connectivity -> outgoing cloud message is queued -> app surfaces offline state -> queued work retries later.
4. User manages history -> search, rename, archive, delete, or export conversations.
5. User compares providers -> switch provider or model per conversation and track usage over time.

### 4.2 Release Scope

- Baseline Release: welcome flow, secure API key entry, Ollama auto-detection, local-only onboarding path, provider CRUD, provider configuration form, provider health check, default model selection, send and receive messages, streaming responses, markdown rendering, code block highlighting, new conversation, stop generation, conversation list, persistent history, delete conversation, provider selector, quick model shortcuts, provider indicator, responsive layout, and offline support.
- Expansion Release: custom Ollama endpoint management, provider parameters, edit message branching, rename conversation, search history, export chat, switch mid-chat, token counting, usage dashboard, spending alerts, and keyboard shortcuts.

## 5. Data Model

### 5.1 Domain Entities

- `Provider`
- `ProviderModel`
- `Conversation`
- `Message`
- `OutboxJob`
- `UsageSnapshot`
- `AppSetting`

### 5.2 Provider Entity

Required fields:

- `id` UUID
- `kind` enum: `ollama`, `openai_compatible`
- `display_name`
- `base_url`
- `api_key_ref` secure storage key reference, nullable for local providers
- `default_model_id`, nullable
- `headers_json`
- `settings_json`
- `health_status`
- `health_checked_at`
- `created_at`
- `updated_at`
- `deleted_at`, nullable

`settings_json` should contain transport and generation defaults such as temperature, max tokens, top_p, timeout, and provider-specific flags.

### 5.3 ProviderModel Entity

- `id` UUID
- `provider_id`
- `remote_model_id`
- `display_name`
- `context_window`, nullable
- `supports_streaming`
- `supports_tools`
- `last_used_at`
- `created_at`
- `updated_at`

### 5.4 Conversation Entity

- `id` UUID
- `title`
- `selected_provider_id`
- `selected_model_id`
- `pinned_at`, nullable
- `archived_at`, nullable
- `deleted_at`, nullable
- `created_at`
- `updated_at`

### 5.5 Message Entity

- `id` UUID
- `conversation_id`
- `role` enum: `system`, `user`, `assistant`
- `content_markdown`
- `status` enum: `draft`, `queued`, `sending`, `streaming`, `completed`, `failed`, `cancelled`
- `provider_id`, nullable
- `model_id`, nullable
- `sequence_no`
- `edited_from_message_id`, nullable
- `generation_group_id`, nullable
- `input_tokens`, nullable
- `output_tokens`, nullable
- `estimated_cost_micros`, nullable
- `error_code`, nullable
- `error_message`, nullable
- `response_metadata_json`, nullable
- `created_at`
- `updated_at`

`generation_group_id` is required to support future edit-and-regenerate branching without losing history integrity.

### 5.6 OutboxJob Entity

- `id` UUID
- `conversation_id`
- `message_id`
- `provider_id`
- `payload_json`
- `status` enum: `pending`, `processing`, `retry_wait`, `failed`, `completed`, `cancelled`
- `retry_count`
- `next_retry_at`
- `last_error`
- `created_at`
- `updated_at`

### 5.7 AppSetting Entity

- `key`
- `value_json`
- `updated_at`

Initial required keys:

- `has_completed_onboarding`
- `skip_cloud_providers`
- `monthly_spend_threshold`
- `show_code_line_numbers`
- `last_successful_ollama_endpoint`

### 5.8 Initial SQLite Schema

Required tables:

- `app_settings`
- `providers`
- `provider_models`
- `conversations`
- `messages`
- `outbox_jobs`

Recommended indexes:

- `idx_conversations_updated_at`
- `idx_conversations_deleted_at`
- `idx_messages_conversation_id_sequence_no`
- `idx_messages_generation_group_id`
- `idx_messages_created_at`
- `idx_outbox_jobs_status_next_retry_at`
- `idx_provider_models_provider_id_last_used_at`

### 5.9 Migration Strategy

- Schema versioning must start at `1`.
- Every migration must be forward-only and idempotent.
- Destructive data shape changes must be introduced by add-copy-swap or additive columns first.
- Desktop and mobile must share the same logical schema version even if platform initialization differs.

## 6. Provider Abstraction

### 6.1 Adapter Contract

Create a `ChatProviderAdapter` interface with:

- `Future<ProviderValidationResult> validateConfig(Provider provider)`
- `Future<List<ProviderModel>> fetchModels(Provider provider)`
- `Future<ProviderHealthStatus> healthCheck(Provider provider)`
- `Stream<ChatStreamEvent> streamChat(ChatRequest request)`
- `Future<ChatCompletionResult> completeChat(ChatRequest request)` for fallback and tests

### 6.2 Supported Provider Types In Release 1

- Ollama
- OpenAI-compatible HTTP providers

This keeps the model surface coherent while still supporting multiple vendors through a single transport abstraction.

### 6.3 Ollama Rules

- Default endpoint probe: `http://127.0.0.1:11434`
- Health/model probe: `/api/tags`
- Chat endpoint: `/api/chat`
- API key not required by default
- If mDNS discovery is enabled, every discovered candidate must still pass an HTTP probe before being shown as available

### 6.4 OpenAI-Compatible Rules

- Models endpoint: `/models`
- Chat endpoint: `/chat/completions`
- API key required
- Streaming path should support server-sent event style chunking and provider-specific NDJSON fallback through adapter normalization

### 6.5 Provider Schema Definition

Provider configuration forms should not be hardcoded page by page. Each provider type should expose a local schema definition with:

- field id
- label
- field type
- required flag
- validator set
- secure flag
- default value
- help text

Supported field types:

- text
- password
- url
- integer
- double
- dropdown
- key-value map
- checkbox

## 7. Request, Streaming, and Offline Pipeline

### 7.1 Send Message Flow

When a user sends a message:

1. Validate input and selected provider/model.
2. Insert the user message and a placeholder assistant message in one transaction.
3. Transition the assistant message to `sending`.
4. Open the provider stream.
5. Buffer streamed deltas in memory for smooth UI updates.
6. Persist partial content periodically, not on every token.
7. Finalize status, usage, and metadata on completion.

### 7.2 Streaming Rules

- UI update cadence may be as fast as 16 to 50 ms.
- Database writes should be throttled more aggressively, such as every 250 to 500 ms or on stream completion, to avoid I/O churn.
- Cancellation must close the HTTP stream, stop further writes, and preserve partial output already received.
- If a stream fails after partial output, the message should remain visible with `failed` status and an option to retry.

### 7.3 Offline Queue Rules

Queue only messages that target remote providers. Local Ollama messages should fail fast if the local endpoint is unavailable rather than pretending they can be delivered later.

Queued job behavior:

- create one `outbox_jobs` record per message send attempt
- retry with exponential backoff
- retry on app resume, connectivity restoration, and explicit manual retry
- background retry only where the platform permits it

### 7.4 Error Categories

- validation error
- network unavailable
- request timeout
- authentication failure
- rate limit
- unsupported model
- provider stream parse error
- user cancelled
- unexpected internal error

Each category must map to:

- user message copy
- log severity
- retry eligibility
- UI call to action

## 8. Security and Privacy Requirements

- API keys must never be written to SQLite, shared preferences, logs, or exports.
- Secret values must be masked in all forms and confirmation screens.
- Logs must redact `Authorization`, `api-key`, and similar headers.
- Exported chat files must not include provider secrets or raw request headers.
- The app must support a local-only mode where cloud providers are skipped entirely.
- Deleting a provider must also delete its secure storage secret entry if no other provider references it.

## 9. Detailed Functional Requirements

Each requirement below defines implementation-ready behavior.

### 9.1 Onboarding And Setup

#### FR-ONB-1 Welcome Flow

- Show onboarding only when `has_completed_onboarding` is false and no prior provider or conversation exists.
- Provide three pages: product value, privacy/local-first message, and setup choices.
- User may advance, skip, or complete the flow.
- Persist completion state in `shared_preferences`.
- Returning users must never see onboarding again unless manually reset from settings.

Acceptance:

- First launch shows onboarding.
- Relaunch after completion bypasses onboarding.
- App survives interruption mid-flow and resumes safely.

#### FR-ONB-2 Secure API Key Entry

- Show masked text input with reveal toggle.
- Validate format according to provider schema before save.
- Store API key in secure storage and only persist a secure storage reference in SQLite.
- Support update, replace, and delete flows.
- If secure storage write fails, provider save must abort atomically.

Acceptance:

- API key is retrievable for outbound requests.
- Plaintext key is absent from SQLite and logs.
- Invalid formats block save with clear inline errors.

#### FR-ONB-3 Ollama Auto-Detection

- Probe localhost with a short timeout during setup.
- Optionally scan the LAN for candidate services, then validate each candidate by HTTP probe.
- If detection fails, offer manual entry without blocking onboarding completion.
- Cache the last successful Ollama endpoint.

Acceptance:

- Detected instance can be selected and used immediately.
- Manual entry remains available even when auto-detection fails.

#### FR-ONB-4 Skip Onboarding / Local Only

- Provide a "Local Only" choice during onboarding.
- Set a persistent flag that suppresses cloud-provider nudges.
- Persist `skip_cloud_providers = true` in app settings.
- Preselect Ollama-first setup paths throughout the app.

Acceptance:

- User can reach the main app without adding a cloud provider.

### 9.2 Provider Management

#### FR-PRV-1 Provider CRUD

- Providers can be created, edited, soft deleted, and restored from undo.
- Persist changes through repository transactions.
- List order: active providers first, then by last updated desc.
- Deleting a provider currently used by a conversation must require confirmation and choose a fallback behavior.

Acceptance:

- Provider list updates reactively.
- Undo restores the deleted provider and its non-secret metadata.

#### FR-PRV-2 Provider Configuration Form

- Generate forms from provider schema definitions.
- Validate required fields, URL format, header map shape, and model selection dependencies.
- Support custom headers as key-value pairs with duplicate-key prevention.
- Support per-provider generation parameters.

Acceptance:

- Same form engine can render both Ollama and OpenAI-compatible providers.

#### FR-PRV-3 Provider Health Check

- Run health checks on save, on manual refresh, and opportunistically on app start.
- Use a 10-second timeout for health probes unless a provider definition overrides it.
- Cache status for five minutes unless the user explicitly refreshes.
- Display healthy, degraded, and unreachable states with explanatory text, not only color.

Acceptance:

- Health state is visible from both provider list and provider detail screens.

#### FR-PRV-4 Default Model Selection

- Allow selection of a default model per provider.
- Refresh model list before save if the selected model is stale or missing.
- New conversations inherit provider default unless user overrides it.

Acceptance:

- Newly created conversations use the chosen default model automatically.

#### FR-PRV-5 Custom Ollama Endpoint

- User may manually set a LAN or remote Ollama endpoint.
- Validate by probing the endpoint before enabling save.
- Mark endpoints as local, LAN, or remote for later UX decisions.

Acceptance:

- Valid custom endpoints appear in provider selection and survive restart.

#### FR-PRV-6 Provider Parameters

- Support temperature, max tokens, and top_p in provider defaults.
- Allow reset to provider defaults.
- Validate numeric ranges before save.

Acceptance:

- Saved defaults are applied to outbound requests unless conversation overrides are added later.

### 9.3 Chat Interface

#### FR-CHT-1 Send / Receive Messages

- Compose box auto-resizes within a bounded height and responds correctly to keyboard visibility changes.
- Send action is disabled for empty or whitespace-only messages.
- Double-submit protection prevents duplicate sends from rapid taps or keypresses.
- User message is committed to storage before network dispatch.

Acceptance:

- One user action results in one stored message and one assistant placeholder.

#### FR-CHT-2 Streaming Responses

- Responses stream incrementally into the visible assistant bubble.
- The parser normalizes provider chunk formats into a single event model.
- Streaming state survives transient widget rebuilds.
- Completion, cancellation, and failure states are clearly distinct.
- UI token rendering should target a 16 ms update cadence, with a configurable fallback up to 50 ms on lower-end devices.

Acceptance:

- Long responses remain responsive and memory usage does not grow unbounded.

#### FR-CHT-3 Markdown Rendering

- Render CommonMark-compatible content with a controlled style sheet.
- Sanitize or constrain HTML fallback so provider output cannot inject unsafe UI.
- Preserve code fences, headings, tables, lists, blockquotes, and links.

Acceptance:

- Messages render consistently across supported platforms.

#### FR-CHT-4 Code Block Highlighting

- Detect fenced code blocks and language hints.
- Provide per-block copy button.
- Support a broad language set through the selected highlighting package.
- Make line numbers optional through a user setting, default off.

Acceptance:

- Copy action copies only the code content, not UI decorations.

#### FR-CHT-5 New Conversation

- User can create a new conversation from FAB, menu, or keyboard shortcut where supported.
- New conversation receives UUID and default provider/model context.
- Focus returns to the input field after creation.

Acceptance:

- New chat is immediately ready for input.

#### FR-CHT-6 Stop Generation

- Active requests expose a stop control.
- Stop action cancels transport and marks message `cancelled`.
- Partial content remains visible.

Acceptance:

- Stopping does not leave the UI in a permanently loading state.

#### FR-CHT-7 Edit Message

- User may edit a prior user message from the current conversation.
- Editing creates a new active generation branch from that point onward rather than mutating history destructively.
- Messages after the edited point are marked superseded for display filtering and auditability.

Acceptance:

- Original history remains recoverable.
- Regenerated branch becomes the active visible path.

### 9.4 Conversation Management

#### FR-CNV-1 Conversation List

- List conversations with pagination or incremental loading, using an initial page size of 20 items.
- Sort pinned first, then most recently updated.
- Support swipe or contextual actions for pin, archive, delete.
- Support pull-to-refresh on platforms where that gesture is conventional.
- Show empty state guidance when no conversations exist.

Acceptance:

- List remains performant with at least 1000 conversations.

#### FR-CNV-2 Persistent History

- Conversation and message history persists across restarts.
- All writes are transaction-safe.
- Foreign keys remain enabled on every database open.

Acceptance:

- Killing and reopening the app does not lose committed messages.

#### FR-CNV-3 Delete Conversation

- Deletion is soft delete using `deleted_at`.
- Messages under a deleted conversation are excluded from default queries.
- Provide undo window and a 30-day retention policy before purge.

Acceptance:

- Deleted conversations disappear from normal list immediately and can be purged after retention expires.

#### FR-CNV-4 Rename Conversation

- User may rename a conversation inline or through a dialog.
- If no custom title exists, system may suggest a title derived from the first user message.

Acceptance:

- Rename is visible across list and detail views instantly.

#### FR-CNV-5 Search History

- Search must cover conversation title and message content.
- Implement with SQLite FTS5 where available; provide a fallback LIKE search only if platform support forces it.
- Debounce input by 300 ms.

Acceptance:

- Search results display matching snippets and highlight terms.

#### FR-CNV-6 Export Chat

- Export a single conversation as Markdown or JSON.
- Filename pattern should be deterministic and human readable.
- JSON export contains metadata and active branch only by default.
- Markdown export preserves role labels and code fences.

Acceptance:

- Exported files open correctly in standard tools.

### 9.5 Provider Switching

#### FR-SWT-1 Provider Selector

- Provide an AppBar selector with search.
- Persist selected provider and model per conversation.
- Hide deleted or unhealthy providers unless the user explicitly expands unavailable entries.

Acceptance:

- Switching selection updates the next outbound request context only.

#### FR-SWT-2 Quick Model Shortcuts

- Surface the three most recently used models as chips.
- Updating a chip also updates the conversation-level selected model.

Acceptance:

- Recent model list remains scoped to available models for the chosen provider.

#### FR-SWT-3 Provider Indicator

- Show current provider name and model in the chat header.
- Indicator must be tappable and open the selector.

Acceptance:

- User can always tell which provider will handle the next message.

#### FR-SWT-4 Switch Mid-Chat

- User may change provider/model before sending the next turn.
- Insert a visible system divider marking the switch.
- Conversation context continues as text history, with no attempt to translate provider-specific hidden state.

Acceptance:

- Transcript clearly shows when the active provider changed.

### 9.6 Cost Tracking

#### FR-CST-1 Token Counting

- Prefer provider-reported usage when available.
- Use tokenizer-based estimation only when the provider does not return usage.
- Store counts per completed assistant message and optionally per user message send.
- For streamed responses without provider usage metadata, allow a fallback estimate based on tokenizer output or a temporary character-count heuristic.

Acceptance:

- Message records contain usage data or an explicit `estimated` flag.

#### FR-CST-2 Usage Dashboard

- Aggregate usage daily, weekly, and monthly.
- Separate local vs cloud usage.
- Display token totals, estimated spend, and optional "money saved" metric for local chats.

Acceptance:

- Dashboard totals reconcile with underlying message records.

#### FR-CST-3 Spending Alerts

- User may define monthly threshold.
- Show local notification and in-app banner when threshold is approached or exceeded.
- When possible, suggest local model alternatives after a threshold alert is triggered.
- Alert should fire once per threshold crossing, not on every app open.

Acceptance:

- Alert history prevents duplicate spam.

### 9.7 Platform And Offline

#### FR-PLT-1 Responsive Layout

- Mobile: single-pane navigation.
- Tablet/Desktop: conversation list plus chat pane, with room for detail actions.
- Breakpoint handling must be deterministic and testable.

Acceptance:

- Major screens remain usable from narrow phone widths to desktop windows.

#### FR-PLT-2 Offline Support

- Surface online/offline banner.
- Queue remote sends while offline.
- Resume sync when conditions allow.
- Protect battery by enforcing backoff and avoiding tight polling loops.

Acceptance:

- User can compose while offline and see queued state clearly.

#### FR-PLT-3 Keyboard Shortcuts

- Support desktop shortcuts for new chat, send, and stop.
- Use platform-appropriate modifiers.
- Mobile platforms ignore shortcut registration safely.

Acceptance:

- Desktop shortcuts work without interfering with text editing conventions.

## 10. User Interface Specification

### 10.1 App Shell

Primary screens:

- onboarding
- conversation list
- chat detail
- provider management
- settings
- usage dashboard

### 10.2 Navigation Model

- Mobile: bottom or drawer navigation to main sections; chat list pushes into detail
- Tablet/Desktop: persistent list pane and detail pane
- Modals: provider editor, rename dialog, export sheet, delete confirmations

### 10.3 Conversation Title Rules

- Explicit user title wins
- Otherwise derive from first user message
- Truncate to a safe display length
- Update only until the user manually renames it

### 10.4 Status UI States

Messages:

- sending
- streaming
- queued
- failed
- cancelled
- completed

Providers:

- healthy
- degraded
- unreachable
- never_checked

Global app:

- first_run
- loading
- offline
- syncing
- empty_state

## 11. Non-Functional Requirements

### 11.1 Performance

- Cold app launch to interactive shell: target under 3 seconds on mid-range devices after first install.
- Conversation list load: under 300 ms for the first page from local DB.
- New message insert transaction: under 100 ms in normal conditions.
- Stream rendering must avoid visible UI jank during long outputs.

### 11.2 Reliability

- No committed user message may be lost once the send action completes.
- Failures must degrade to a visible and retryable state.
- Database integrity checks should run in debug tooling and optionally on startup after crash recovery.

### 11.3 Security

- Secrets stored only in secure storage.
- TLS required for remote HTTPS endpoints unless the user explicitly opts into insecure local development behavior.
- Sensitive headers redacted in logs.

### 11.4 Accessibility

- Support screen readers for major controls.
- Maintain minimum touch targets.
- Do not encode health state or failure state using color alone.

### 11.5 Observability

- Use structured logging categories: database, providers, streaming, sync, ui
- Provide debug-only request tracing with secret redaction
- Capture stream lifecycle events for troubleshooting

## 12. Testing Strategy

### 12.1 Unit Tests

- repositories and migrations
- provider adapter normalization
- validation logic
- token counting and usage aggregation
- offline retry policy

### 12.2 Widget Tests

- onboarding flow
- provider form validation
- conversation list actions
- chat composer states
- markdown and code block rendering

### 12.3 Integration Tests

- add provider -> health check -> fetch models
- send message with streamed response
- cancel in-flight response
- queue while offline -> retry when online
- export chat

### 12.4 Manual Test Matrix

- Android
- iOS
- Windows
- macOS
- Linux

Manual focus areas:

- secure storage behavior
- local Ollama discovery
- desktop resizing
- keyboard shortcuts
- notification permissions

## 13. Delivery Plan And Phase Gates

### 13.1 Phase 0: Foundation

Deliverables:

- Flutter project bootstrap
- dependency setup
- app shell skeleton
- logging
- environment/config scaffolding
- database bootstrap with migrations

Exit gate:

- app launches on all target platforms
- database opens successfully
- routing shell is in place

### 13.2 Phase 1: Core Persistence And Provider Setup

Implements:

- FR-ONB-1 to FR-ONB-4
- FR-PRV-1 to FR-PRV-4
- base secure storage integration

Exit gate:

- user can complete onboarding
- add a provider
- validate it
- select a default model

### 13.3 Phase 2: Core Chat

Implements:

- FR-CHT-1 to FR-CHT-6
- FR-CNV-2
- core provider adapters

Exit gate:

- user can create a conversation, send a message, stream a reply, and stop generation

### 13.4 Phase 3: Conversation Operations

Implements:

- FR-CNV-1
- FR-CNV-3
- FR-CNV-4
- FR-SWT-1 to FR-SWT-3

Exit gate:

- history list is stable, sortable, and manageable

### 13.5 Phase 4: Responsive And Offline Behavior

Implements:

- FR-PLT-1
- FR-PLT-2
- desktop-aware send queue behavior

Exit gate:

- major flows work on mobile and desktop
- offline queue is observable and retryable

### 13.6 Phase 5: Expansion Features

Implements:

- FR-PRV-5
- FR-PRV-6
- FR-CHT-7
- FR-CNV-5
- FR-CNV-6
- FR-SWT-4
- FR-PLT-3

Exit gate:

- expansion-scope features are stable and do not regress core chat flows

### 13.7 Phase 6: Usage And Alerts

Implements:

- FR-CST-1
- FR-CST-2
- FR-CST-3

Exit gate:

- usage numbers aggregate correctly and alerts fire once per threshold crossing

## 14. Critical Path

The critical path for a usable first release is:

1. platform bootstrap and database layer
2. secure storage
3. provider CRUD and validation
4. provider adapters and model fetch
5. conversation persistence
6. send/stream/stop flows
7. responsive shell
8. offline queue baseline

If any of these are incomplete, the product will appear feature rich on paper but not deliver a dependable core chat loop.

## 15. Risk Register

### 15.1 Provider API Variance

Risk: "OpenAI-compatible" providers often diverge subtly in streaming format, model metadata, headers, or error payloads.  
Mitigation: normalize everything through adapters and keep raw HTTP handling out of UI code.

### 15.2 Background Work On Desktop

Risk: background scheduling is not uniform across platforms.  
Mitigation: treat background sync as an enhancement, not the only retry path.

### 15.3 History Branching Complexity

Risk: edit-and-regenerate introduces branching semantics that can corrupt linear history if bolted on later.  
Mitigation: include `generation_group_id` and superseded-message handling from the start even if the UI ships later.

### 15.4 Large Transcript Performance

Risk: markdown rendering and syntax highlighting can become expensive on very large chats.  
Mitigation: use lazy list rendering, partial persistence, and controlled re-render boundaries.

### 15.5 Secret Handling Regressions

Risk: debug logs or exports may accidentally leak secrets.  
Mitigation: centralize redaction utilities and add tests that assert secrets never appear in serialized output.

## 16. Estimated Delivery Effort

Estimated effort by feature domain:

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
