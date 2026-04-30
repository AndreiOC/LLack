import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/entities.dart';

/// Data Access Object for OutboxJob operations
class OutboxJobDao {
  final Database _db;

  OutboxJobDao(this._db);

  /// Get all pending jobs ordered by retry time
  Future<List<OutboxJob>> getPending() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await _db.query(
      'outbox_jobs',
      where: 'status = ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [OutboxJobStatus.pending.storageName, now],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => OutboxJob.fromJson(m)).toList();
  }

  /// Get all retry-wait jobs that are ready
  Future<List<OutboxJob>> getReadyForRetry() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await _db.query(
      'outbox_jobs',
      where: 'status = ? AND next_retry_at <= ?',
      whereArgs: [OutboxJobStatus.retryWait.storageName, now],
      orderBy: 'next_retry_at ASC',
    );
    return maps.map((m) => OutboxJob.fromJson(m)).toList();
  }

  /// Get jobs for a conversation
  Future<List<OutboxJob>> getByConversationId(String conversationId) async {
    final maps = await _db.query(
      'outbox_jobs',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => OutboxJob.fromJson(m)).toList();
  }

  /// Get job by ID
  Future<OutboxJob?> getById(String id) async {
    final maps = await _db.query(
      'outbox_jobs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return OutboxJob.fromJson(maps.first);
  }

  /// Insert new job
  Future<void> insert(OutboxJob job) async {
    await _db.insert('outbox_jobs', job.toJson());
  }

  /// Update job status to processing
  Future<void> markProcessing(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'outbox_jobs',
      {
        'status': OutboxJobStatus.processing.storageName,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update job for retry
  Future<void> markForRetry(String id, int retryCount, String lastError) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final backoffSeconds = 1 << retryCount; // Exponential backoff
    final nextRetry =
        now + (backoffSeconds > 300 ? 300 : backoffSeconds) * 1000;

    await _db.update(
      'outbox_jobs',
      {
        'status': OutboxJobStatus.retryWait.storageName,
        'retry_count': retryCount,
        'last_error': lastError,
        'next_retry_at': nextRetry,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark job as completed
  Future<void> markCompleted(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'outbox_jobs',
      {
        'status': OutboxJobStatus.completed.storageName,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark job as failed (max retries reached)
  Future<void> markFailed(String id, String error) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'outbox_jobs',
      {
        'status': OutboxJobStatus.failed.storageName,
        'last_error': error,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reset a retry-wait or failed job back to pending for immediate processing.
  Future<void> resetToPending(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'outbox_jobs',
      {
        'status': OutboxJobStatus.pending.storageName,
        'next_retry_at': null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark job as cancelled
  Future<void> markCancelled(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'outbox_jobs',
      {
        'status': OutboxJobStatus.cancelled.storageName,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete completed/cancelled/failed jobs older than threshold
  Future<int> purgeOldJobs(Duration threshold) async {
    final cutoff = DateTime.now().subtract(threshold).millisecondsSinceEpoch;
    return await _db.delete(
      'outbox_jobs',
      where: 'status IN (?, ?, ?) AND updated_at < ?',
      whereArgs: [
        OutboxJobStatus.completed.storageName,
        OutboxJobStatus.cancelled.storageName,
        OutboxJobStatus.failed.storageName,
        cutoff,
      ],
    );
  }

  /// Delete job by ID
  Future<void> delete(String id) async {
    await _db.delete(
      'outbox_jobs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get job by message ID
  Future<OutboxJob?> getByMessageId(String messageId) async {
    final maps = await _db.query(
      'outbox_jobs',
      where: 'message_id = ?',
      whereArgs: [messageId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return OutboxJob.fromJson(maps.first);
  }

  /// Get count of pending jobs
  Future<int> getPendingCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM outbox_jobs WHERE status IN (?, ?)',
      [OutboxJobStatus.pending.storageName, OutboxJobStatus.retryWait.storageName],
    );
    return result.first['count'] as int? ?? 0;
  }
}
