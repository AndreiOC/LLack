import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop keyboard shortcut definitions.
/// Call [registerShortcuts] from a StatefulWidget's initState.
class ChatKeyboardShortcuts {
  final VoidCallback onNewConversation;
  final VoidCallback onSendMessage;
  final VoidCallback onStopGeneration;

  ChatKeyboardShortcuts({
    required this.onNewConversation,
    required this.onSendMessage,
    required this.onStopGeneration,
  });

  late final Map<ShortcutActivator, VoidCallback> _shortcuts;

  void register() {
    _shortcuts = <ShortcutActivator, VoidCallback>{
      // Ctrl/Cmd + N: New conversation
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): onNewConversation,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): onNewConversation,
      // Ctrl/Cmd + Enter: Send message
      const SingleActivator(LogicalKeyboardKey.enter, meta: true): onSendMessage,
      const SingleActivator(LogicalKeyboardKey.enter, control: true): onSendMessage,
      // Escape: Stop generation
      const SingleActivator(LogicalKeyboardKey.escape): onStopGeneration,
    };
  }

  Map<ShortcutActivator, VoidCallback> get shortcuts => _shortcuts;
}
