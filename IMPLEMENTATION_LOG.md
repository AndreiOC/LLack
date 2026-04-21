# FOSS Chat Implementation Log

## Session 4: 2025-04-22 — TODO Completion Pass

### Agent
Kimi K2.6 Preview (Max Power Mode)

### What Was Done
Implemented all 4 remaining TODOs from Session 3's code review follow-ups.

---

### TODO 1: Adapter Error Migration ✅

**Problem:** Adapters threw generic `Exception`s instead of typed `ChatError` subclasses.

**Fix:** Updated both `OllamaAdapter` and `OpenAiCompatibleAdapter`:
- Added `_mapDioException()` helper that maps `DioException` to:
  - `NetworkError` — timeouts, connection failures, DNS errors (retryable)
  - `AuthError` — 401/403 responses (not retryable)
  - `ClientError` — 4xx responses (not retryable)
  - `ProviderError` — 5xx responses, parse errors (retryable via `isRetryable=true`)
  - `CancellationError` — user-cancelled streams
- Added `_mapDioStatusCode()` for non-Dio HTTP errors
- Replaced all `throw Exception(...)` with `throw _mapDioException(e)` or typed errors
- Imported `chat_errors.dart` and `provider_model_repository.dart` into both adapters

**Files:**
- `lib/data/services/adapters/ollama_adapter.dart`
- `lib/data/services/adapters/openai_compatible_adapter.dart`

---

### TODO 2: Outbox Integration ✅

**Problem:** Failed sends showed an error but didn't queue for retry.

**Fix:** Updated `ChatStateNotifier.sendMessage()` in `chat_state_provider.dart`:
- Added `OutboxService` dependency via `_ensureDependencies()`
- Added `_isOffline()` check using `InternetAddress.lookup()` (fallback until connectivity_plus is added)
- Added `_isRetryableError()` helper — `NetworkError` and `ProviderError(isRetryable=true)` are retryable; `AuthError`, `ClientError`, `CancellationError` are not
- When offline → immediately enqueues to outbox via `_enqueueToOutbox()`
- When `ChatError` with retryable error → enqueues to outbox instead of failing
- Non-retryable errors → show error immediately as before
- `_enqueueToOutbox()` creates conversation if needed, persists placeholder messages, marks assistant message as `MessageStatus.queued`, and stores full payload for retry
- Added `outboxServiceProvider` wiring (already existed in `repository_providers.dart`)

**Files:**
- `lib/app/providers/chat_state_provider.dart`
- `lib/app/providers/chat_service_provider.dart` (cleaned duplicate provider)

---

### TODO 3: Model Caching ✅

**Problem:** `fetchModels()` hit the provider API on every UI interaction.

**Fix:** Updated both adapters:
- Added optional `ProviderModelRepository? _modelRepo` constructor param
- Added `_modelCacheTtl = Duration(minutes: 5)`
- Added `_isCacheFresh()` helper checking `ProviderModel.updatedAt`
- In `fetchModels()`: check cache first → if fresh, return cached → otherwise fetch from provider → persist to cache → return results
- Cache persistence failures are non-fatal (wrapped in try/catch)

**Files:**
- `lib/data/services/adapters/ollama_adapter.dart`
- `lib/data/services/adapters/openai_compatible_adapter.dart`

---

### TODO 4: Lifecycle Integration ✅

**Problem:** Outbox polling ran at full speed even in background, draining battery.

**Fix:** Updated `OutboxService`:
- Extended `WidgetsBindingObserver` for automatic lifecycle detection
- Added `_isBackgrounded` flag
- Added `_foregroundPollInterval` (30s) and `_backgroundPollInterval` (2min)
- `startPolling()` picks interval based on background state
- `onAppBackgrounded()` / `onAppForegrounded()` public methods for manual control
- `didChangeAppLifecycleState()` handles `paused`, `detached`, `hidden` (background) and `resumed`, `inactive` (foreground)

**Files:**
- `lib/data/services/outbox_service.dart`

---

### Files Changed (This Session)
- `lib/data/services/adapters/ollama_adapter.dart` — Error mapping + model caching
- `lib/data/services/adapters/openai_compatible_adapter.dart` — Error mapping + model caching
- `lib/app/providers/chat_state_provider.dart` — Outbox integration + offline handling
- `lib/app/providers/chat_service_provider.dart` — Removed duplicate outbox provider
- `lib/data/services/outbox_service.dart` — Lifecycle awareness
- `IMPLEMENTATION_LOG.md` — This file

### Status
All 4 TODOs from Session 3 are now implemented. The codebase matches the spec for error handling, offline queue, model caching, and lifecycle management.

---

## Session 3: 2025-04-22 — Code Review & Implementation Pass

### Agent
Kimi K2.6 Preview (Max Power Mode)

### What Was Done
Comprehensive code review of the existing codebase against the FOSS Chat implementation spec. Identified gaps, bugs, and deviations from spec, then implemented fixes.

### Critical Issues Found & Fixed

1. **Orphaned Outbox Queue (CRITICAL)**
   - **Problem:** The `outbox_jobs` table, entity, and DAO existed but no service processed pending jobs. The offline queue was dead code.
   - **Fix:** Created `lib/data/services/outbox_service.dart` — a polling worker that drains pending jobs and delivers them via `ChatService`. Includes exponential backoff, max retry limits, and clean start/stop lifecycle.
   - **Integration:** Added `outboxServiceProvider` in `repository_providers.dart` so the service is available via Riverpod.

2. **Orphaned Provider Models Table (CRITICAL)**
   - **Problem:** The `provider_models` table existed in schema but had no DAO, no repository, and no code that used it. The `fetchModels` methods returned `List<ProviderModel>` but results were never persisted.
   - **Fix:** Created `lib/data/db/dao/provider_model_dao.dart` and `lib/data/repositories/provider_model_repository.dart`. Added `providerModelDaoProvider` and `providerModelRepositoryProvider`.
   - **Note:** Adapters still don't cache models automatically — that integration is a TODO for future work.

3. **Missing Error Categorization (Section 7.4)**
   - **Problem:** The spec calls for explicit error categories (network, auth, provider, client) with retry semantics. Code threw generic `Exception`s everywhere.
   - **Fix:** Created `lib/domain/errors/chat_errors.dart` with sealed class hierarchy: `NetworkError`, `AuthError`, `ProviderError`, `ClientError`, `CancellationError`. Each carries retry semantics.
   - **Note:** Adapters don't yet throw these typed errors — that migration is a TODO.

4. **Missing Database Trigger**
   - **Problem:** The spec (Section 5) requires a trigger `trg_messages_updated_at` to auto-update `updated_at` on message updates. This was missing.
   - **Fix:** Added trigger to both `database_config.dart` fallback schema and `assets/migrations/001_initial_schema.sql`.

5. **Missing Migration Asset**
   - **Problem:** The code referenced `assets/migrations/001_initial_schema.sql` but the directory and file didn't exist. The fallback embedded schema worked, but this violated spec conventions.
   - **Fix:** Created `assets/migrations/001_initial_schema.sql` with full schema including indexes and trigger. Added assets directory to `pubspec.yaml`.

### Minor Issues Fixed

6. **DAO Barrel Export Missing**
   - Added `provider_model_dao.dart` export to `lib/data/db/dao/dao.dart`.

7. **Repository Barrel Export Missing**
   - Added `provider_model_repository.dart` export to `lib/data/repositories/repositories.dart`.

### Remaining Gaps (TODOs) — ALL COMPLETED IN SESSION 4

- ~~TODO: Adapters need to throw typed `ChatError` subclasses~~ ✅ Done
- ~~TODO: Outbox integration into `ChatStateNotifier`~~ ✅ Done
- ~~TODO: Provider model caching in adapters~~ ✅ Done
- ~~TODO: Outbox polling should respect app lifecycle~~ ✅ Done
- **TODO:** The `updated_at` trigger is only on `messages` — per spec, `conversations` and `providers` may also benefit from triggers, but DAOs already handle this explicitly.

### Files Changed (Session 3)
- `lib/data/db/database_config.dart` — Added trigger, kept fallback schema
- `lib/data/db/dao/dao.dart` — Added provider_model_dao export
- `lib/data/db/dao/provider_model_dao.dart` — NEW
- `lib/data/repositories/repositories.dart` — Added provider_model_repository export
- `lib/data/repositories/provider_model_repository.dart` — NEW
- `lib/data/services/outbox_service.dart` — NEW
- `lib/domain/errors/chat_errors.dart` — NEW
- `lib/app/providers/repository_providers.dart` — Added providerModelDaoProvider, outboxJobDaoProvider, providerModelRepositoryProvider, outboxServiceProvider
- `pubspec.yaml` — Added assets section for migrations
- `assets/migrations/001_initial_schema.sql` — NEW
- `IMPLEMENTATION_LOG.md` — This file

### Status
All critical orphaned features now have service-layer implementations. Integration points remain as TODOs for future sessions.
