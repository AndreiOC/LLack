# FOSS Chat Code Review Report — Session 3

**Reviewer:** Kimi K2.6 Preview (Max Power Mode)  
**Date:** 2025-04-22  
**Scope:** Full codebase review against implementation spec

---

## Executive Summary

The codebase is well-structured and largely spec-compliant. The domain model, database schema, provider adapters, streaming pipeline, and secure storage all match the spec. However, three critical features were **orphaned** — schema/tables existed but no code used them. This review identifies those gaps and implements the missing service layers.

**Severity Breakdown:**
- 3 Critical issues (orphaned features)
- 1 Moderate issue (missing error taxonomy)
- 2 Minor issues (missing exports, missing assets)

---

## Critical Issues

### 1. Orphaned Outbox Queue

**Severity:** Critical  
**Spec Section:** 5.2, 7.5

**Finding:** The `outbox_jobs` table exists in schema with proper indexes. `OutboxJob` entity and `OutboxJobDao` are fully implemented with retry logic, exponential backoff, and status transitions. **However, no service or worker ever polls or processes pending jobs.** The offline queue is dead code.

**Impact:** If the app goes offline during a message send, the message will fail and never retry. The outbox table is purely decorative.

**Fix:** Created `OutboxService` in `lib/data/services/outbox_service.dart` with:
- `startPolling()` / `stopPolling()` lifecycle
- 30-second polling interval
- Processes both `pending` and `retryWait` jobs
- Delivers via `ChatService.sendMessage()`
- Exponential backoff with max 5 retries
- `enqueue()`, `cancelJob()`, `purgeOldJobs()` for UI integration

**Remaining Work:** `ChatStateNotifier` doesn't enqueue failed sends to the outbox yet. Integration is a TODO.

---

### 2. Orphaned Provider Models Table

**Severity:** Critical  
**Spec Section:** 5.2

**Finding:** The `provider_models` table exists in schema with `provider_id` FK, `remote_model_id`, `display_name`, `context_window`, `supports_streaming`, `supports_tools`, and `last_used_at`. **However, no DAO, repository, or service touches this table.** The `fetchModels()` methods in adapters return `List<ProviderModel>` but results are never persisted.

**Impact:** Every time the user opens model selection, the app must re-fetch models from the provider. No local cache exists. The `last_used_at` field is never written.

**Fix:** Created:
- `ProviderModelDao` in `lib/data/db/dao/provider_model_dao.dart`
- `ProviderModelRepository` in `lib/data/repositories/provider_model_repository.dart`
- Riverpod providers for both

**Remaining Work:** Adapters don't auto-cache after `fetchModels()`. Integration is a TODO.

---

### 3. Missing Error Categorization (Section 7.4)

**Severity:** Critical  
**Spec Section:** 7.4

**Finding:** The spec defines four error categories with distinct retry semantics:
- `NetworkError` — retry with exponential backoff
- `AuthError` — never retry, prompt user
- `ProviderError` — retry for rate limits, never for model-not-found
- `ClientError` — never retry

**Current code throws generic `Exception` everywhere.** The outbox has retry logic but no categorization to drive it intelligently.

**Fix:** Created `lib/domain/errors/chat_errors.dart` with sealed class hierarchy:
```dart
sealed class ChatError implements Exception { ... }
class NetworkError extends ChatError { final bool isRetryable; }
class AuthError extends ChatError { }
class ProviderError extends ChatError { final bool isRetryable; }
class ClientError extends ChatError { }
class CancellationError extends ChatError { }
```

**Remaining Work:** Adapters need to throw these instead of generic `Exception`s. This requires per-adapter refactoring to map HTTP status codes and Dio errors to the correct category.

---

## Moderate Issues

### 4. Missing `updated_at` Trigger

**Severity:** Moderate  
**Spec Section:** 5.2

**Finding:** The spec requires a trigger `trg_messages_updated_at` to auto-update `updated_at` on message updates. DAOs manually set `updated_at`, but the trigger is a safety net.

**Fix:** Added trigger to both fallback schema and `assets/migrations/001_initial_schema.sql`.

---

## Minor Issues

### 5. Missing Migration Asset

**Severity:** Minor  
**Spec Section:** 5.2

**Finding:** Code referenced `assets/migrations/001_initial_schema.sql` but the file didn't exist. The embedded fallback schema worked, but this is not spec-compliant.

**Fix:** Created the migration file and added `assets/migrations/` to `pubspec.yaml`.

---

### 6. Missing Barrel Exports

**Severity:** Minor

**Finding:** New DAO and repository files weren't exported in barrel files.

**Fix:** Updated `lib/data/db/dao/dao.dart` and `lib/data/repositories/repositories.dart`.

---

## What Was NOT Changed

The following areas were reviewed and found correct. No changes made:

- **Database schema** — Matches spec Section 5 exactly
- **Entities** — All match domain model
- **Provider adapters** — Interface and implementations match spec Section 6
- **Streaming pipeline** — `streamChat`/`completeChat` correctly handle SSE, JSON, cancellation
- **Secure storage** — Uses `flutter_secure_storage` with platform encryption
- **Conversation/Message CRUD** — DAOs and repositories are correct
- **Onboarding flow** — Well-implemented per spec
- **UI styling** — Matches the warm-neutral design intent

---

## Remaining TODOs — ALL COMPLETED IN SESSION 4

1. ~~Adapter error migration~~ ✅ Done — Both adapters now map HTTP errors to `ChatError` subclasses with retry eligibility
2. ~~Outbox integration~~ ✅ Done — `ChatStateNotifier` enqueues retryable failures to `OutboxService`; offline sends go straight to outbox
3. ~~Model caching~~ ✅ Done — Adapters persist `fetchModels()` results via `ProviderModelRepository` with 5-min TTL
4. ~~Lifecycle integration~~ ✅ Done — `OutboxService` is now a `WidgetsBindingObserver` with background/foreground polling intervals
5. **Trigger coverage** — Consider adding `updated_at` triggers for `conversations` and `providers`

---

## Verdict

The codebase is solid and spec-compliant at the structural level. The main gaps were **orphaned features** — schema existed but service layer was missing. Sessions 3 and 4 closed all gaps by implementing the missing service and repository layers, migrating adapters to typed errors, integrating the outbox into the chat flow, adding model caching, and making the outbox lifecycle-aware.

**Status:** All critical TODOs completed. The implementation matches the spec for error handling, offline messaging, model caching, and lifecycle management.
