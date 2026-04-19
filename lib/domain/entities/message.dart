/// Message entity representing a chat message
class Message {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String contentMarkdown;
  final MessageStatus status;
  final String? providerId;
  final String? modelId;
  final int sequenceNo;
  final String? editedFromMessageId;
  final String? generationGroupId;
  final int? inputTokens;
  final int? outputTokens;
  final int? estimatedCostMicros;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? responseMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.contentMarkdown,
    required this.status,
    this.providerId,
    this.modelId,
    required this.sequenceNo,
    this.editedFromMessageId,
    this.generationGroupId,
    this.inputTokens,
    this.outputTokens,
    this.estimatedCostMicros,
    this.errorCode,
    this.errorMessage,
    this.responseMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        role: MessageRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => MessageRole.user,
        ),
        contentMarkdown: json['content_markdown'] as String,
        status: MessageStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => MessageStatus.draft,
        ),
        providerId: json['provider_id'] as String?,
        modelId: json['model_id'] as String?,
        sequenceNo: json['sequence_no'] as int,
        editedFromMessageId: json['edited_from_message_id'] as String?,
        generationGroupId: json['generation_group_id'] as String?,
        inputTokens: json['input_tokens'] as int?,
        outputTokens: json['output_tokens'] as int?,
        estimatedCostMicros: json['estimated_cost_micros'] as int?,
        errorCode: json['error_code'] as String?,
        errorMessage: json['error_message'] as String?,
        responseMetadata: json['response_metadata_json'] != null
            ? Map<String, dynamic>.from(json['response_metadata_json'] as Map)
            : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role.name,
        'content_markdown': contentMarkdown,
        'status': status.name,
        'provider_id': providerId,
        'model_id': modelId,
        'sequence_no': sequenceNo,
        'edited_from_message_id': editedFromMessageId,
        'generation_group_id': generationGroupId,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        'estimated_cost_micros': estimatedCostMicros,
        'error_code': errorCode,
        'error_message': errorMessage,
        'response_metadata_json': responseMetadata,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Message.user({
    required String id,
    required String conversationId,
    required String content,
    required int sequenceNo,
  }) =>
      Message(
        id: id,
        conversationId: conversationId,
        role: MessageRole.user,
        contentMarkdown: content,
        status: MessageStatus.completed,
        sequenceNo: sequenceNo,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  factory Message.assistantPlaceholder({
    required String id,
    required String conversationId,
    required int sequenceNo,
    String? providerId,
    String? modelId,
  }) =>
      Message(
        id: id,
        conversationId: conversationId,
        role: MessageRole.assistant,
        contentMarkdown: '',
        status: MessageStatus.sending,
        providerId: providerId,
        modelId: modelId,
        sequenceNo: sequenceNo,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Message copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    String? contentMarkdown,
    MessageStatus? status,
    String? providerId,
    String? modelId,
    int? sequenceNo,
    String? editedFromMessageId,
    String? generationGroupId,
    int? inputTokens,
    int? outputTokens,
    int? estimatedCostMicros,
    String? errorCode,
    String? errorMessage,
    Map<String, dynamic>? responseMetadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Message(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        role: role ?? this.role,
        contentMarkdown: contentMarkdown ?? this.contentMarkdown,
        status: status ?? this.status,
        providerId: providerId ?? this.providerId,
        modelId: modelId ?? this.modelId,
        sequenceNo: sequenceNo ?? this.sequenceNo,
        editedFromMessageId: editedFromMessageId ?? this.editedFromMessageId,
        generationGroupId: generationGroupId ?? this.generationGroupId,
        inputTokens: inputTokens ?? this.inputTokens,
        outputTokens: outputTokens ?? this.outputTokens,
        estimatedCostMicros: estimatedCostMicros ?? this.estimatedCostMicros,
        errorCode: errorCode ?? this.errorCode,
        errorMessage: errorMessage ?? this.errorMessage,
        responseMetadata: responseMetadata ?? this.responseMetadata,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isSystem => role == MessageRole.system;
  bool get isEditable => isUser && status == MessageStatus.completed;
  bool get canRetry => status == MessageStatus.failed || status == MessageStatus.cancelled;
  bool get isStreaming => status == MessageStatus.streaming;
  bool get isFinal => status == MessageStatus.completed || status == MessageStatus.failed || status == MessageStatus.cancelled;
  bool get hasTokens => inputTokens != null || outputTokens != null;
}

/// Message role enum
enum MessageRole {
  system,
  user,
  assistant,
}

/// Message status enum
enum MessageStatus {
  draft,
  queued,
  sending,
  streaming,
  completed,
  failed,
  cancelled,
}