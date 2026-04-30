import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:intl/intl.dart';

import '../../app/providers/providers.dart';
import '../../data/services/usage_service.dart';
import '../../domain/entities/entities.dart';
import '../providers/provider_management_sheet.dart';
import 'usage_dashboard_sheet.dart';

class ChatWorkspace extends ConsumerStatefulWidget {
  const ChatWorkspace({super.key});

  @override
  ConsumerState<ChatWorkspace> createState() => _ChatWorkspaceState();
}

class _ChatWorkspaceState extends ConsumerState<ChatWorkspace> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _lastShownError;
  bool _isSending = false;

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
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
          onDeleteConversation: (conversationId) async {
            await ref
                .read(conversationListProvider.notifier)
                .deleteConversation(conversationId);
            if (chatAsync.valueOrNull?.conversationId == conversationId) {
              await ref
                  .read(chatStateProvider.notifier)
                  .prepareNewConversation();
            }
          },
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
                  showDrawerButton: !isWide,
                  onProviderSelected: (provider) async {
                    await ref
                        .read(chatStateProvider.notifier)
                        .selectProvider(provider);
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
                  onOpenUsageDashboard: _openUsageDashboard,
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
          body: body,
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
}

class _ConversationRail extends ConsumerWidget {
  final AsyncValue<List<Conversation>> conversationsAsync;
  final String selectedConversationId;
  final Future<void> Function() onNewConversation;
  final Future<void> Function(String conversationId) onOpenConversation;
  final Future<void> Function(String conversationId) onDeleteConversation;
  final Future<void> Function(String conversationId) onTogglePin;
  final Future<void> Function(String conversationId) onArchive;

  const _ConversationRail({
    required this.conversationsAsync,
    required this.selectedConversationId,
    required this.onNewConversation,
    required this.onOpenConversation,
    required this.onDeleteConversation,
    required this.onTogglePin,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              onPressed: onNewConversation,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New conversation'),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: conversationsAsync.when(
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return Center(
                      child: Text(
                        'No conversations yet.\nStart a new thread to begin.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFCFBCA8),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
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
                            conversation.id == selectedConversationId;
                        return _ConversationTile(
                          conversation: conversation,
                          isSelected: isSelected,
                          onTap: () => onOpenConversation(conversation.id),
                          onDelete: () => onDeleteConversation(conversation.id),
                          onTogglePin: () => onTogglePin(conversation.id),
                          onArchive: () => onArchive(conversation.id),
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

  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
    required this.onArchive,
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
}

enum _ConversationAction { pin, archive, delete }

class _ChatPanel extends StatelessWidget {
  final ChatState chatState;
  final List<Provider> providers;
  final AsyncValue<UsageOverview> usageOverviewAsync;
  final ScrollController scrollController;
  final TextEditingController composerController;
  final bool showDrawerButton;
  final Future<void> Function(Provider provider) onProviderSelected;
  final Future<void> Function() onSendMessage;
  final Future<void> Function() onCancelStream;
  final Future<void> Function(String messageId) onRetryMessage;
  final Future<void> Function(String messageId) onDeleteMessage;
  final Future<void> Function() onOpenUsageDashboard;
  final Future<void> Function() onOpenProviderManagement;
  final Future<void> Function(UsageThresholdState state) onDismissUsageBanner;
  final Future<void> Function() onRestartOnboarding;

  const _ChatPanel({
    required this.chatState,
    required this.providers,
    required this.usageOverviewAsync,
    required this.scrollController,
    required this.composerController,
    required this.showDrawerButton,
    required this.onProviderSelected,
    required this.onSendMessage,
    required this.onCancelStream,
    required this.onRetryMessage,
    required this.onDeleteMessage,
    required this.onOpenUsageDashboard,
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
          onOpenUsageDashboard: onOpenUsageDashboard,
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
                    );
                  },
                ),
        ),
        _Composer(
          controller: composerController,
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

class _ChatHeader extends StatelessWidget {
  final bool showDrawerButton;
  final String title;
  final Provider selectedProvider;
  final String? selectedModelId;
  final List<Provider> providers;
  final Future<void> Function(Provider provider) onProviderSelected;
  final Future<void> Function() onOpenUsageDashboard;
  final Future<void> Function() onOpenProviderManagement;

  const _ChatHeader({
    required this.showDrawerButton,
    required this.title,
    required this.selectedProvider,
    required this.selectedModelId,
    required this.providers,
    required this.onProviderSelected,
    required this.onOpenUsageDashboard,
    required this.onOpenProviderManagement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

              final modelChip = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6D7C8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.tune_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(selectedModelId ?? 'No default model'),
                  ],
                ),
              );

              if (constraints.maxWidth < 700) {
                return Column(
                  children: <Widget>[
                    providerDropdown,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: modelChip),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: providerDropdown),
                  const SizedBox(width: 12),
                  modelChip,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

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

  const _MessageBubble({
    required this.message,
    required this.onDelete,
    this.onRetry,
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
                  Text(
                    isUser ? 'You' : 'Assistant',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foregroundColor.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
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
    };
    return '$status · $time';
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isStreaming;
  final String selectedProviderName;
  final String? selectedModelId;
  final Future<void> Function() onSend;
  final Future<void> Function() onCancel;

  const _Composer({
    required this.controller,
    required this.isStreaming,
    required this.selectedProviderName,
    required this.selectedModelId,
    required this.onSend,
    required this.onCancel,
  });

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
                '$selectedProviderName${selectedModelId != null ? ' · $selectedModelId' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF7C6A59),
                ),
              ),
              const Spacer(),
              if (isStreaming)
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
                  controller: controller,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
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
                onPressed: isStreaming ? onCancel : onSend,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 54),
                  backgroundColor: isStreaming
                      ? const Color(0xFF8C3D3D)
                      : const Color(0xFFB85C38),
                ),
                child: Text(isStreaming ? 'Stop' : 'Send'),
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
