/// Outbox job status enum
enum OutboxJobStatus {
  pending,
  processing,
  retryWait,
  failed,
  completed,
  cancelled,
}

/// Outbox job entity for offline message queue
class OutboxJob {
  final String id;
  final String conversationId;
  final String messageId;
  final String providerId;
  final Map<String, dynamic> payload;
  final OutboxJobStatus status;
  final int retryCount;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  OutboxJob({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.providerId,
    required this.payload,
    required this.status,
    this.retryCount = 0,
    this.nextRetryAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OutboxJob.fromJson(Map<String, dynamic> json) => OutboxJob(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        messageId: json['message_id'] as String,
        providerId: json['provider_id'] as String,
        payload: Map<String, dynamic>.from(json['payload_json'] as Map),
        status: OutboxJobStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => OutboxJobStatus.pending,
        ),
        retryCount: json['retry_count'] as int? ?? 0,
        nextRetryAt: json['next_retry_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['next_retry_at'] as int)
            : null,
        lastError: json['last_error'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'message_id': messageId,
        'provider_id': providerId,
        'payload_json': payload,
        'status': status.name,
        'retry_count': retryCount,
        'next_retry_at': nextRetryAt?.millisecondsSinceEpoch,
        'last_error': lastError,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory OutboxJob.create({
    required String id,
    required String conversationId,
    required String messageId,
    required String providerId,
    required Map<String, dynamic> payload,
  }) => OutboxJob(
        id: id,
        conversationId: conversationId,
        messageId: messageId,
        providerId: providerId,
        payload: payload,
        status: OutboxJobStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  OutboxJob copyWith({
    String? id,
    String? conversationId,
    String? messageId,
    String? providerId,
    Map<String, dynamic>? payload,
    OutboxJobStatus? status,
    int? retryCount,
    DateTime? nextRetryAt,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OutboxJob(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        messageId: messageId ?? this.messageId,
        providerId: providerId ?? this.providerId,
        payload: payload ?? this.payload,
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
        lastError: lastError ?? this.lastError,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get isPending => status == OutboxJobStatus.pending;
  bool get isProcessing => status == OutboxJobStatus.processing;
  bool get isRetryable => status == OutboxJobStatus.failed || status == OutboxJobStatus.retryWait;
  bool get isCompleted => status == OutboxJobStatus.completed;
  bool get isCancelled => status == OutboxJobStatus.cancelled;
  
  bool get shouldRetry => isRetryable && retryCount < 5;
  
  Duration get nextRetryDelay {
    // Exponential backoff: 2^retryCount seconds
    final seconds = 1 << retryCount;
    return Duration(seconds: seconds > 300 ? 300 : seconds);
  }
}