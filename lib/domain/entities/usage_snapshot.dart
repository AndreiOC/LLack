/// Usage snapshot entity for cost tracking
/// Per spec section 5.1, 5.7, and 9.6
class UsageSnapshot {
  final String id;
  final String? conversationId;
  final String? messageId;
  final String? providerId;
  final String? modelId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String periodType; // 'daily', 'weekly', 'monthly'
  final int inputTokens;
  final int outputTokens;
  final int estimatedCostMicros;
  final bool isLocal;
  final DateTime createdAt;

  UsageSnapshot({
    required this.id,
    this.conversationId,
    this.messageId,
    this.providerId,
    this.modelId,
    required this.periodStart,
    required this.periodEnd,
    required this.periodType,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.estimatedCostMicros = 0,
    this.isLocal = false,
    required this.createdAt,
  });

  factory UsageSnapshot.fromJson(Map<String, dynamic> json) => UsageSnapshot(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String?,
        messageId: json['message_id'] as String?,
        providerId: json['provider_id'] as String?,
        modelId: json['model_id'] as String?,
        periodStart:
            DateTime.fromMillisecondsSinceEpoch(json['period_start'] as int),
        periodEnd:
            DateTime.fromMillisecondsSinceEpoch(json['period_end'] as int),
        periodType: json['period_type'] as String,
        inputTokens: json['input_tokens'] as int? ?? 0,
        outputTokens: json['output_tokens'] as int? ?? 0,
        estimatedCostMicros: json['estimated_cost_micros'] as int? ?? 0,
        isLocal: (json['is_local'] as int? ?? 0) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'message_id': messageId,
        'provider_id': providerId,
        'model_id': modelId,
        'period_start': periodStart.millisecondsSinceEpoch,
        'period_end': periodEnd.millisecondsSinceEpoch,
        'period_type': periodType,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        'estimated_cost_micros': estimatedCostMicros,
        'is_local': isLocal ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  UsageSnapshot copyWith({
    String? id,
    String? conversationId,
    String? messageId,
    String? providerId,
    String? modelId,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? periodType,
    int? inputTokens,
    int? outputTokens,
    int? estimatedCostMicros,
    bool? isLocal,
    DateTime? createdAt,
  }) =>
      UsageSnapshot(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        messageId: messageId ?? this.messageId,
        providerId: providerId ?? this.providerId,
        modelId: modelId ?? this.modelId,
        periodStart: periodStart ?? this.periodStart,
        periodEnd: periodEnd ?? this.periodEnd,
        periodType: periodType ?? this.periodType,
        inputTokens: inputTokens ?? this.inputTokens,
        outputTokens: outputTokens ?? this.outputTokens,
        estimatedCostMicros: estimatedCostMicros ?? this.estimatedCostMicros,
        isLocal: isLocal ?? this.isLocal,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Total tokens (input + output)
  int get totalTokens => inputTokens + outputTokens;

  /// Estimated cost in dollars
  double get estimatedCostDollars => estimatedCostMicros / 1_000_000;
}
