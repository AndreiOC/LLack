import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:intl/intl.dart';

import '../../app/providers/providers.dart';
import '../../data/services/usage_service.dart';
import '../../domain/entities/entities.dart';
import '../providers/provider_management_sheet.dart';
import 'code_block_builder.dart';
import 'connectivity_banner.dart';
import 'export_service.dart';
import 'keyboard_shortcuts.dart';
import 'usage_dashboard_sheet.dart';
import '../settings/settings_screen.dart';

class ChatWorkspace extends ConsumerStatefulWidget {
  const ChatWorkspace({super.key});

  @override
  ConsumerState<ChatWorkspace> createState() => _ChatWorkspaceState();
}

class _ChatWorkspaceState extends ConsumerState<ChatWorkspace> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  String? _lastShownError;
  bool _isSending = false;
  late final ChatKeyboardShortcuts _keyboardShortcuts;

  @override
  void initState() {
    super.initState();
    _keyboardShortcuts = ChatKeyboardShortcuts(
      onNewConversation: () async {
        await ref.read(chatStateProvider.notifier).prepareNewConversation();
        _composerFocusNode.requestFocus();
      },
      onSendMessage: _sendMessage,
      onStopGeneration: () async {
        await ref.read(chatStateProvider.notifier).cancelStream();
      },
    );
    _keyboardShortcuts.register();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ChatState>>(chatStateProvider, (previous, next) {
      final previousState = previous?.valueOrNull;
      final currentState = next.valueOrNull;

      final errorMessage =
          next.hasError ? next.error.toString() : currentState?.error;
      if (errorMessage != null && errorMessage != _lastShownError) {
        _lastShownError = errorMessage;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
        });
      }

      final messageCountChanged =
          previousState?.messages.length != currentState?.messages.length;
      final streamingChanged =
          previousState?.streamingContent != currentState?.streamingContent;
      if (messageCountChanged || streamingChanged) {
        _scheduleScrollToBottom();
      }
    });

    final theme = Theme.of(context);
    final conversationsAsync = ref.watch(conversationListProvider);
    final chatAsync = ref.watch(chatStateProvider);
    final providersAsync = ref.watch(providerManagementProvider);
    final usageOverviewAsync = ref.watch(usageOverviewProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final rail = _ConversationRail(
          conversationsAsync: conversationsAsync,
          selectedConversationId: chatAsync.valueOrNull?.conversationId ?? '',
          onNewConversation: () async {
            await ref.read(chatStateProvider.notifier).prepareNewConversation();
            _composerFocusNode.requestFocus();
          },
          onOpenConversation: (conversationId) async {
            final navigator = Navigator.of(context);
            await ref
                .read(chatStateProvider.notifier)
                .loadConversation(conversationId);
            if (!isWide && mounted) {
              navigator.maybePop();
            }
          },
          onDeleteConversation: (conversationId) =>
              _deleteConversation(conversationId, conversationsAsync, chatAsync),
          onTogglePin: (conversationId) async {
            await ref
                .read(conversationListProvider.notifier)
                .togglePin(conversationId);
          },
          onArchive: (conversationId) async {
            await ref
                .read(conversationListProvider.notifier)
                .archive(conversationId);
            if (chatAsync.valueOrNull?.conversationId == conversationId) {
              await ref
                  .read(chatStateProvider.notifier)
                  .prepareNewConversation();
            }
          },
          onRename: (conversationId, newTitle) async {
            await ref
                .read(conversationListProvider.notifier)
                .rename(conversationId, newTitle);
          },
          onExport: (conversation) => _exportConversation(conversation),
        );

        final body = DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Color(0xFFFFFBF7),
                Color(0xFFF5EEE6),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: chatAsync.when(
              data: (chatState) {
                final providers =
                    providersAsync.valueOrNull ?? const <Provider>[];
                return _ChatPanel(
                  chatState: chatState,
                  providers: providers,
                  usageOverviewAsync: usageOverviewAsync,
                  scrollController: _scrollController,
                  composerController: _composerController,
                  composerFocusNode: _composerFocusNode,
                  showDrawerButton: !isWide,
                  onProviderSelected: (provider) async {
                    await ref
                        .read(chatStateProvider.notifier)
                        .selectProvider(provider);
                  },
                  onModelSelected: (modelId) async {
                    await ref
                        .read(chatStateProvider.notifier)
                        .selectModel(modelId);
                  },
                  onSendMessage: _sendMessage,
                  onCancelStream: () async {
                    await ref.read(chatStateProvider.notifier).cancelStream();
                  },
                  onRetryMessage: (messageId) async {
                    await ref
                        .read(chatStateProvider.notifier)
                        .retryMessage(messageId);
                  },
                  onDeleteMessage: (messageId) async {
                    await ref
                        .read(chatStateProvider.notifier)
                        .deleteMessage(messageId);
                  },
                  onEditMessage: (messageId, newContent) async {
                    await ref
                        .read(chatStateProvider.notifier)
                        .editMessage(messageId, newContent);
                  },
                  onOpenUsageDashboard: _openUsageDashboard,
                  onOpenSettings: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  onOpenProviderManagement: _openProviderManagement,
                  onDismissUsageBanner: _dismissUsageBanner,
                  onRestartOnboarding: () async {
                    await ref.read(onboardingProvider.notifier).reopen();
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.error_outline_rounded, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load chat state',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('$error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(chatStateProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        if (isWide) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                SizedBox(width: 320, child: rail),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          drawer: Drawer(
            child: SafeArea(child: rail),
          ),
          body: CallbackShortcuts(
            bindings: _keyboardShortcuts.shortcuts,
            child: Focus(
              autofocus: true,
              child: ConnectivityBanner(child: body),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    _isSending = true;
    _composerController.clear();
    try {
      await ref.read(chatStateProvider.notifier).sendMessage(text);
      await ref.read(conversationListProvider.notifier).refresh();
      _composerFocusNode.requestFocus();
    } finally {
      _isSending = false;
    }
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openUsageDashboard() async {
    ref.invalidate(usageOverviewProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const UsageDashboardSheet(),
    );
  }

  Future<void> _openProviderManagement() async {
    await showProviderManagementSheet(context);
  }

  Future<void> _dismissUsageBanner(UsageThresholdState state) async {
    final usageService = await ref.read(usageServiceProvider.future);
    await usageService.acknowledgeThresholdBanner(state: state);
    ref.invalidate(usageOverviewProvider);
  }

  Future<void> _exportConversation(Conversation conversation) async {
    final messages = await ref
        .read(chatServiceProvider.future)
        .then((s) => s.getMessages(conversation.id));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Export as Markdown'),
              onTap: () async {
                Navigator.pop(context);
                await ExportService.shareMarkdown(conversation, messages);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_outlined),
              title: const Text('Export as JSON'),
              onTap: () async {
                Navigator.pop(context);
                await ExportService.shareJson(conversation, messages);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteConversation(
    String conversationId,
    AsyncValue<List<Conversation>> conversationsAsync,
    AsyncValue<ChatState> chatAsync,
  ) async {
    final conversation = conversationsAsync.valueOrNull
        ?.firstWhere((c) => c.id == conversationId);
    final scaffoldContext = context;
    await ref
        .read(conversationListProvider.notifier)
        .deleteConversation(conversationId);
    if (chatAsync.valueOrNull?.conversationId == conversationId) {
      await ref.read(chatStateProvider.notifier).prepareNewConversation();
    }
    if (conversation != null && mounted) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(scaffoldContext)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('"${conversation.title}" deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await ref
                    .read(conversationListProvider.notifier)
                    .restoreConversation(conversationId);
              },
            ),
          ),
        );
    }
  }
}

class _ConversationRail extends ConsumerStatefulWidget {
  final AsyncValue<List<Conversation>> conversationsAsync;
  final String selectedConversationId;
  final Future<void> Function() onNewConversation;
  final Future<void> Function(String conversationId) onOpenConversation;
  final Future<void> Function(String conversationId) onDeleteConversation;
  final Future<void> Function(String conversationId) onTogglePin;
  final Future<void> Function(String conversationId) onArchive;
  final Future<void> Function(String conversationId, String newTitle) onRename;
  final Future<void> Function(Conversation conversation) onExport;

  const _ConversationRail({
    required this.conversationsAsync,
    required this.selectedConversationId,
    required this.onNewConversation,
    required this.onOpenConversation,
    required this.onDeleteConversation,
    required this.onTogglePin,
    required this.onArchive,
    required this.onRename,
    required this.onExport,
  });

  @override
  ConsumerState<_ConversationRail> createState() => _ConversationRailState();
}

class _ConversationRailState extends ConsumerState<_ConversationRail> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    await ref.read(conversationListProvider.notifier).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF2C241D),
            Color(0xFF1D1814),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'FOSS Chat',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A local-first inbox for your models.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFCFBCA8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: widget.onNewConversation,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New conversation'),
            ),
            const SizedBox(height: 12),
            // Search field
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: const TextStyle(color: Color(0xFFCFBCA8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFCFBCA8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFFCFBCA8)),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                          setState(() => _isSearching = false);
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0x1AF7F1EA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (value) {
                setState(() => _isSearching = value.isNotEmpty);
                _performSearch(value);
              },
            ),
            const SizedBox(height: 18),
            Expanded(
              child: widget.conversationsAsync.when(
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return Center(
                      child: Text(
                        _isSearching
                            ? 'No matches found.'
                            : 'No conversations yet.\nStart a new thread to begin.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFCFBCA8),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      _searchController.clear();
                      setState(() => _isSearching = false);
                      await ref
                          .read(conversationListProvider.notifier)
                          .refresh();
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final isSelected =
                            conversation.id == widget.selectedConversationId;
                        return _ConversationTile(
                          conversation: conversation,
                          isSelected: isSelected,
                          onTap: () => widget.onOpenConversation(conversation.id),
                          onDelete: () => widget.onDeleteConversation(conversation.id),
                          onTogglePin: () => widget.onTogglePin(conversation.id),
                          onArchive: () => widget.onArchive(conversation.id),
                          onRename: (newTitle) => widget.onRename(conversation.id, newTitle),
                          onExport: () => widget.onExport(conversation),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    '$error',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFFFD7D7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final VoidCallback onArchive;
  final ValueChanged<String> onRename;
  final VoidCallback onExport;

  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
    required this.onArchive,
    required this.onRename,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d · HH:mm');

    return Material(
      color: isSelected ? const Color(0xFF4C3A2B) : const Color(0x1AF7F1EA),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  color: conversation.isPinned
                      ? const Color(0xFFE9C46A)
                      : const Color(0xFFB85C38),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      conversation.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(conversation.updatedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFCFBCA8),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_ConversationAction>(
                iconColor: const Color(0xFFCFBCA8),
                itemBuilder: (context) => <PopupMenuEntry<_ConversationAction>>[
                  PopupMenuItem<_ConversationAction>(
                    value: _ConversationAction.pin,
                    child: Text(conversation.isPinned ? 'Unpin' : 'Pin'),
                  ),
                  const PopupMenuItem<_ConversationAction>(
                    value: _ConversationAction.rename,
                    child: Text('Rename'),
                  ),
                  const PopupMenuItem<_ConversationAction>(
                    value: _ConversationAction.export,
                    child: Text('Export'),
                  ),
                  const PopupMenuItem<_ConversationAction>(
                    value: _ConversationAction.archive,
                    child: Text('Archive'),
                  ),
                  const PopupMenuItem<_ConversationAction>(
                    value: _ConversationAction.delete,
                    child: Text('Delete'),
                  ),
                ],
                onSelected: (action) {
                  switch (action) {
                    case _ConversationAction.pin:
                      onTogglePin();
                      break;
                    case _ConversationAction.rename:
                      _showRenameDialog(context);
                      break;
                    case _ConversationAction.export:
                      onExport();
                      break;
                    case _ConversationAction.archive:
                      onArchive();
                      break;
                    case _ConversationAction.delete:
                      onDelete();
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: conversation.title);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Title'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              onRename(value.trim());
            }
            Navigator.of(context).pop();
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                onRename(value);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

enum _ConversationAction { pin, rename, export, archive, delete }

class _ChatPanel extends StatelessWidget {
  final ChatState chatState;
  final List<Provider> providers;
  final AsyncValue<UsageOverview> usageOverviewAsync;
  final ScrollController scrollController;
  final TextEditingController composerController;
  final FocusNode composerFocusNode;
  final bool showDrawerButton;
  final Future<void> Function(Provider provider) onProviderSelected;
  final Future<void> Function(String modelId) onModelSelected;
  final Future<void> Function() onSendMessage;
  final Future<void> Function() onCancelStream;
  final Future<void> Function(String messageId) onRetryMessage;
  final Future<void> Function(String messageId) onDeleteMessage;
  final Future<void> Function(String messageId, String newContent) onEditMessage;
  final Future<void> Function() onOpenUsageDashboard;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onOpenProviderManagement;
  final Future<void> Function(UsageThresholdState state) onDismissUsageBanner;
  final Future<void> Function() onRestartOnboarding;

  const _ChatPanel({
    required this.chatState,
    required this.providers,
    required this.usageOverviewAsync,
    required this.scrollController,
    required this.composerController,
    required this.composerFocusNode,
    required this.showDrawerButton,
    required this.onProviderSelected,
    required this.onModelSelected,
    required this.onSendMessage,
    required this.onCancelStream,
    required this.onRetryMessage,
    required this.onDeleteMessage,
    required this.onEditMessage,
    required this.onOpenUsageDashboard,
    required this.onOpenSettings,
    required this.onOpenProviderManagement,
    required this.onDismissUsageBanner,
    required this.onRestartOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return _EmptyProviderState(
        onRestartOnboarding: onRestartOnboarding,
        onOpenProviderManagement: onOpenProviderManagement,
      );
    }

    final selectedProvider = chatState.selectedProvider ?? providers.first;
    final selectedModelId = chatState.conversation?.selectedModelId ??
        selectedProvider.defaultModelId;

    return Column(
      children: <Widget>[
        _ChatHeader(
          showDrawerButton: showDrawerButton,
          title: chatState.conversation?.title ?? 'Fresh thread',
          selectedProvider: selectedProvider,
          selectedModelId: selectedModelId,
          providers: providers,
          onProviderSelected: onProviderSelected,
          onModelSelected: onModelSelected,
          onOpenUsageDashboard: onOpenUsageDashboard,
          onOpenSettings: onOpenSettings,
          onOpenProviderManagement: onOpenProviderManagement,
        ),
        if (usageOverviewAsync.valueOrNull case final overview?
            when overview.shouldShowThresholdBanner)
          _UsageBanner(
            overview: overview,
            onOpenUsageDashboard: onOpenUsageDashboard,
            onDismiss: () => onDismissUsageBanner(overview.thresholdState),
          ),
        Expanded(
          child: chatState.messages.isEmpty
              ? _EmptyConversationState(selectedProvider: selectedProvider)
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  itemCount: chatState.messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final message = chatState.messages[index];
                    return _MessageBubble(
                      message: message,
                      onRetry: message.canRetry
                          ? () => onRetryMessage(message.id)
                          : null,
                      onDelete: () => onDeleteMessage(message.id),
                      onEdit: message.isEditable
                          ? (newContent) => onEditMessage(message.id, newContent)
                          : null,
                    );
                  },
                ),
        ),
        _Composer(
          controller: composerController,
          focusNode: composerFocusNode,
          isStreaming: chatState.isStreaming,
          selectedProviderName: selectedProvider.displayName,
          selectedModelId: selectedModelId,
          onSend: onSendMessage,
          onCancel: onCancelStream,
        ),
      ],
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  final bool showDrawerButton;
  final String title;
  final Provider selectedProvider;
  final String? selectedModelId;
  final List<Provider> providers;
  final Future<void> Function(Provider provider) onProviderSelected;
  final Future<void> Function(String modelId) onModelSelected;
  final Future<void> Function() onOpenUsageDashboard;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onOpenProviderManagement;

  const _ChatHeader({
    required this.showDrawerButton,
    required this.title,
    required this.selectedProvider,
    required this.selectedModelId,
    required this.providers,
    required this.onProviderSelected,
    required this.onModelSelected,
    required this.onOpenUsageDashboard,
    required this.onOpenSettings,
    required this.onOpenProviderManagement,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cachedModelsAsync =
        ref.watch(_cachedModelsProvider(selectedProvider.id));
    final recentModels = cachedModelsAsync.valueOrNull ?? const <ProviderModel>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 20, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F1E7),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE7D7C4)),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              if (showDrawerButton)
                Builder(
                  builder: (context) {
                    return IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    );
                  },
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF2B1D12),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Responses stream directly into the thread.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5F4634),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onOpenProviderManagement,
                icon: const Icon(Icons.hub_outlined),
                tooltip: 'Manage providers',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onOpenUsageDashboard,
                icon: const Icon(Icons.query_stats_rounded),
                tooltip: 'Usage dashboard',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final providerDropdown = DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6D7C8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedProvider.id,
                      isExpanded: true,
                      items: providers
                          .map(
                            (provider) => DropdownMenuItem<String>(
                              value: provider.id,
                              child: Text(provider.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) {
                          return;
                        }
                        final provider = providers.firstWhere(
                          (candidate) => candidate.id == value,
                        );
                        await onProviderSelected(provider);
                      },
                    ),
                  ),
                ),
              );

              final modelDropdown = DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6D7C8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedModelId,
                      isExpanded: true,
                      hint: const Text('Select model'),
                      items: [
                        ...recentModels.map(
                          (model) => DropdownMenuItem<String>(
                            value: model.remoteModelId,
                            child: Text(model.displayName),
                          ),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        await onModelSelected(value);
                      },
                    ),
                  ),
                ),
              );

              final quickChips = recentModels.take(3).isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      children: recentModels.take(3).map((model) {
                        final isSelected = model.remoteModelId == selectedModelId;
                        return ActionChip(
                          label: Text(model.displayName),
                          backgroundColor: isSelected
                              ? const Color(0xFFB85C38)
                              : Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF2B1D12),
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFFB85C38)
                                : const Color(0xFFE6D7C8),
                          ),
                          onPressed: () => onModelSelected(model.remoteModelId),
                        );
                      }).toList(),
                    )
                  : const SizedBox.shrink();

              if (constraints.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    providerDropdown,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: modelDropdown),
                    if (recentModels.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      quickChips,
                    ],
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: providerDropdown),
                      const SizedBox(width: 12),
                      Expanded(child: modelDropdown),
                    ],
                  ),
                  if (recentModels.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    quickChips,
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Riverpod provider for cached models of a specific provider.
final _cachedModelsProvider =
    FutureProvider.family<List<ProviderModel>, String>(
  (ref, providerId) async {
    final repo = await ref.watch(providerModelRepositoryProvider.future);
    return repo.getByProviderId(providerId);
  },
);

class _UsageBanner extends StatelessWidget {
  static final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: '\$');

  final UsageOverview overview;
  final Future<void> Function() onOpenUsageDashboard;
  final Future<void> Function() onDismiss;

  const _UsageBanner({
    required this.overview,
    required this.onOpenUsageDashboard,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final (background, icon, title) = switch (overview.thresholdState) {
      UsageThresholdState.exceeded => (
          const Color(0xFFFBE4DF),
          Icons.warning_amber_rounded,
          'Monthly cloud spend exceeded the current threshold.',
        ),
      UsageThresholdState.approaching => (
          const Color(0xFFF9EDD0),
          Icons.insights_rounded,
          'Monthly cloud spend is approaching the current threshold.',
        ),
      UsageThresholdState.none => (
          const Color(0xFFEAF5EA),
          Icons.check_circle_outline_rounded,
          'Monthly cloud spend is within the current threshold.',
        ),
    };

    final threshold = overview.monthlyThresholdDollars;
    final subtitle = threshold == null
        ? 'Set a monthly threshold from the dashboard to surface alerts.'
        : 'Cloud spend is ${_currencyFormat.format(overview.monthlyCloud.estimatedCostDollars)} against a ${_currencyFormat.format(threshold)} budget.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: background,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE6D7C8)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF5F4634)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF2B1D12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF5F4634)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpenUsageDashboard,
            child: const Text('View'),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Dismiss alert',
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;
  final ValueChanged<String>? onEdit;

  const _MessageBubble({
    required this.message,
    required this.onDelete,
    this.onRetry,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final bubbleColor = isUser ? const Color(0xFFB85C38) : Colors.white;
    final foregroundColor = isUser ? Colors.white : const Color(0xFF2B1D12);
    final markdown =
        message.contentMarkdown.trim().isEmpty && message.isStreaming
            ? '_Waiting for first tokens..._'
            : (message.contentMarkdown.trim().isEmpty
                ? '_No content_'
                : message.contentMarkdown);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isUser
                    ? const <BoxShadow>[]
                    : const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        isUser ? 'You' : 'Assistant',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foregroundColor.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (onEdit != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _showEditDialog(context),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: foregroundColor.withValues(alpha: 0.7),
                          ),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit message',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  MarkdownBody(
                    data: markdown,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyLarge?.copyWith(
                        color: foregroundColor,
                        height: 1.55,
                      ),
                      code: theme.textTheme.bodyMedium?.copyWith(
                        color: foregroundColor,
                        fontFamily: 'monospace',
                      ),
                      blockquote: theme.textTheme.bodyLarge?.copyWith(
                        color: foregroundColor.withValues(alpha: 0.88),
                      ),
                    ),
                    builders: {
                      'code': CodeBlockBuilder(),
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  _messageStatusLabel(message),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7C6A59),
                  ),
                ),
                if (message.hasTokens)
                  Text(
                    '${message.inputTokens ?? 0}/${message.outputTokens ?? 0} tok',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7C6A59),
                    ),
                  ),
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: message.contentMarkdown);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 10,
          decoration: const InputDecoration(hintText: 'New content'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                onEdit!(value);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  String _messageStatusLabel(Message message) {
    final time = DateFormat('HH:mm').format(message.updatedAt);
    final status = switch (message.status) {
      MessageStatus.streaming => 'Streaming',
      MessageStatus.failed => 'Failed',
      MessageStatus.cancelled => 'Cancelled',
      MessageStatus.completed => 'Sent',
      MessageStatus.queued => 'Queued',
      MessageStatus.sending => 'Sending',
      MessageStatus.draft => 'Draft',
      MessageStatus.superseded => 'Superseded',
    };
    return '$status · $time';
  }
}

class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isStreaming;
  final String selectedProviderName;
  final String? selectedModelId;
  final Future<void> Function() onSend;
  final Future<void> Function() onCancel;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isStreaming,
    required this.selectedProviderName,
    required this.selectedModelId,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateCanSend);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateCanSend);
    super.dispose();
  }

  void _updateCanSend() {
    final canSend = widget.controller.text.trim().isNotEmpty;
    if (canSend != _canSend && mounted) {
      setState(() => _canSend = canSend);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F1E7),
        border: Border(top: BorderSide(color: Color(0xFFE7D7C4))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${widget.selectedProviderName}${widget.selectedModelId != null ? ' · ${widget.selectedModelId}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF7C6A59),
                ),
              ),
              const Spacer(),
              if (widget.isStreaming)
                Text(
                  'Streaming response...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7C6A59),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) {
                    if (_canSend && !widget.isStreaming) {
                      widget.onSend();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Write a prompt...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFE6D7C8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFE6D7C8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFB85C38)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: widget.isStreaming
                    ? widget.onCancel
                    : (_canSend ? widget.onSend : null),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 54),
                  backgroundColor: widget.isStreaming
                      ? const Color(0xFF8C3D3D)
                      : const Color(0xFFB85C38),
                  disabledBackgroundColor: const Color(0xFFD9C8B8),
                ),
                child: Text(widget.isStreaming ? 'Stop' : 'Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  final Provider selectedProvider;

  const _EmptyConversationState({required this.selectedProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.forum_outlined,
                    size: 48,
                    color: Color(0xFFB85C38),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start the first message',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF2B1D12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The current thread is ready to use ${selectedProvider.displayName}. Send a prompt and the assistant response will stream into this pane.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF5F4634),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyProviderState extends StatelessWidget {
  final Future<void> Function() onRestartOnboarding;
  final Future<void> Function() onOpenProviderManagement;

  const _EmptyProviderState({
    required this.onRestartOnboarding,
    required this.onOpenProviderManagement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.cloud_off_rounded, size: 44),
                  const SizedBox(height: 16),
                  Text(
                    'No providers configured',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You need at least one provider before the chat surface can be used.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onOpenProviderManagement,
                    child: const Text('Add provider'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onRestartOnboarding,
                    child: const Text('Open onboarding'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
