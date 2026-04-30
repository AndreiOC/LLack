import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/entities.dart';

/// Service for exporting conversations to various formats.
class ExportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd_HH-mm');

  /// Export a conversation as Markdown.
  static Future<String> toMarkdown(Conversation conversation, List<Message> messages) async {
    final buffer = StringBuffer();
    buffer.writeln('# ${conversation.title}');
    buffer.writeln();
    buffer.writeln('_Exported on ${DateFormat.yMMMMd().add_Hm().format(DateTime.now())}_');
    buffer.writeln();

    for (final message in messages) {
      if (message.isUser) {
        buffer.writeln('## User');
      } else if (message.isAssistant) {
        buffer.writeln('## Assistant');
      } else {
        buffer.writeln('## System');
      }
      buffer.writeln();
      buffer.writeln(message.contentMarkdown);
      buffer.writeln();
      if (message.modelId != null) {
        buffer.writeln('_Model: ${message.modelId}_');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Export a conversation as JSON.
  static Future<String> toJson(Conversation conversation, List<Message> messages) async {
    final data = <String, dynamic>{
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'conversation': {
        'id': conversation.id,
        'title': conversation.title,
        'created_at': conversation.createdAt.toIso8601String(),
        'updated_at': conversation.updatedAt.toIso8601String(),
      },
      'messages': messages.map((m) => <String, dynamic>{
        'role': m.role.name,
        'content': m.contentMarkdown,
        'status': m.status.name,
        'model_id': m.modelId,
        'sequence_no': m.sequenceNo,
        'created_at': m.createdAt.toIso8601String(),
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Share a conversation as Markdown.
  static Future<void> shareMarkdown(Conversation conversation, List<Message> messages) async {
    final content = await toMarkdown(conversation, messages);
    final fileName = _sanitizeFileName('${conversation.title}_${_dateFormat.format(DateTime.now())}.md');
    await _shareTextFile(content, fileName, 'text/markdown');
  }

  /// Share a conversation as JSON.
  static Future<void> shareJson(Conversation conversation, List<Message> messages) async {
    final content = await toJson(conversation, messages);
    final fileName = _sanitizeFileName('${conversation.title}_${_dateFormat.format(DateTime.now())}.json');
    await _shareTextFile(content, fileName, 'application/json');
  }

  static Future<void> _shareTextFile(String content, String fileName, String mimeType) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path, mimeType: mimeType)], text: 'Exported conversation');
  }

  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\-\.\s]'), '_').replaceAll(RegExp(r'\s+'), '_');
  }
}
