import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/dao/dao.dart';
import '../../data/services/chat_service.dart';
import '../../domain/entities/entities.dart';

/// Service for processing the offline outbox queue.
///
/// The outbox holds messages that could not be sent immediately (e.g., no
/// connectivity). A worker polls pending jobs and attempts to deliver them
/// through the [ChatService]. Jobs retry with exponential backoff up to a
/// maximum number of attempts, after which they are marked failed.
///
/// This service is lifecycle-aware: polling slows down when the app is in the
/// background to avoid draining battery.
///
/// Call [startPolling] to begin background processing and [stopPolling] to
/// shut it down cleanly. On mobile, attach via [WidgetsBindingObserver] or
/// call [onAppBackgrounded]/[onAppForegrounded] directly.
class OutboxService extends WidgetsBindingObserver {
  final OutboxJobDao _outboxDao;
  final ChatService _chatService;
  Timer? _pollTimer;
  bool _isProcessing = false;
  bool _isBackgrounded = false;

  /// Delay between polling cycles when the app is online and jobs exist.
  static const Duration _foregroundPollInterval = Duration(seconds: 30);

  /// Slower interval when backgrounded to save battery.
  static const Duration _backgroundPollInterval = Duration(minutes: 2);

  /// Maximum number of retry attempts before a job is permanently failed.
  static const int _maxRetries = 5;

  OutboxService(this._outboxDao, this._chatService);

  /// Start background polling for outbox jobs.
  void startPolling() {
    stopPolling();
    final interval = _isBackgrounded ? _backgroundPollInterval : _foregroundPollInterval;
    _pollTimer = Timer.periodic(interval, (_) => _processQueue());
    // Run an immediate check.
    unawaited(_processQueue());
  }

  /// Stop background polling.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Whether the polling timer is active.
  bool get isPolling => _pollTimer != null && _pollTimer!.isActive;

  /// Called when the app transitions to background.
  /// Slows polling to conserve battery.
  void onAppBackgrounded() {
    _isBackgrounded = true;
    if (isPolling) {
      startPolling(); // Restarts with background interval
    }
  }

  /// Called when the app transitions to foreground.
  /// Resumes normal polling speed.
  void onAppForegrounded() {
    _isBackgrounded = false;
    if (isPolling) {
      startPolling(); // Restarts with foreground interval
    }
  }

  /// Manually trigger a queue processing cycle.
  Future<void> processQueue() => _processQueue();

  /// Get count of pending jobs (for UI badges).
  Future<int> getPendingCount() => _outboxDao.getPendingCount();

  /// Get all pending jobs for a conversation.
  Future<List<OutboxJob>> getPendingForConversation(String conversationId) {
    return _outboxDao.getByConversationId(conversationId);
  }

  /// Enqueue a new message send job.
  Future<OutboxJob> enqueue({
    required String conversationId,
    required String messageId,
    required String providerId,
    required Map<String, dynamic> payload,
  }) async {
    final job = OutboxJob.create(
      id: _generateId(),
      conversationId: conversationId,
      messageId: messageId,
      providerId: providerId,
      payload: payload,
    );
    await _outboxDao.insert(job);
    return job;
  }

  /// Cancel a pending job.
  Future<void> cancelJob(String jobId) async {
    await _outboxDao.markCancelled(jobId);
  }

  /// Purge completed/cancelled/failed jobs older than [threshold].
  Future<int> purgeOldJobs(Duration threshold) {
    return _outboxDao.purgeOldJobs(threshold);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        onAppForegrounded();
        break;
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // First process jobs that are ready for retry.
      final readyJobs = await _outboxDao.getReadyForRetry();
      for (final job in readyJobs) {
        await _processJob(job);
      }

      // Then process new pending jobs.
      final pendingJobs = await _outboxDao.getPending();
      for (final job in pendingJobs) {
        await _processJob(job);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processJob(OutboxJob job) async {
    await _outboxDao.markProcessing(job.id);

    try {
      // Retry the outbox job by streaming into the existing assistant message.
      // This avoids creating duplicate user/assistant messages.
      await _chatService.retryOutboxJob(job);

      // On success, mark completed.
      await _outboxDao.markCompleted(job.id);
    } catch (error) {
      final nextRetry = job.retryCount + 1;
      if (nextRetry >= _maxRetries) {
        await _outboxDao.markFailed(job.id, '$error');
      } else {
        await _outboxDao.markForRetry(job.id, nextRetry, '$error');
      }
    }
  }

  String _generateId() {
    return const Uuid().v4();
  }
}
