import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:intl/intl.dart';

import '../../app/providers/providers.dart';
import '../../domain/entities/entities.dart';
import 'provider_editor_sheet.dart';

Future<void> showProviderManagementSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.94,
      child: ProviderManagementSheet(),
    ),
  );
}

class ProviderManagementSheet extends ConsumerWidget {
  const ProviderManagementSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final providersAsync = ref.watch(providerManagementProvider);
    final onboardingState = ref.watch(onboardingProvider).valueOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Providers',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Spec FR-PRV-1 to FR-PRV-4: manage providers, default models, health checks, and safe deletion from one surface.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5F4634),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () async {
                    final provider = await showProviderEditorSheet(
                      context,
                      initialKind: onboardingState?.localOnlyMode == true
                          ? ProviderKind.ollama
                          : ProviderKind.openaiCompatible,
                      lastKnownOllamaEndpoint:
                          onboardingState?.lastOllamaEndpoint,
                    );
                    if (provider == null || !context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Saved provider ${provider.displayName}.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add provider'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(providerManagementProvider.notifier)
                        .refreshHealthStatuses(force: true);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh health'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: providersAsync.when(
                data: (providers) {
                  if (providers.isEmpty) {
                    return _EmptyProviderManagementState(
                      onAddProvider: () async {
                        await showProviderEditorSheet(
                          context,
                          initialKind: onboardingState?.localOnlyMode == true
                              ? ProviderKind.ollama
                              : ProviderKind.openaiCompatible,
                          lastKnownOllamaEndpoint:
                              onboardingState?.lastOllamaEndpoint,
                        );
                      },
                    );
                  }

                  return ListView.separated(
                    itemCount: providers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final provider = providers[index];
                      return _ProviderCard(
                        provider: provider,
                        onEdit: () async {
                          await showProviderEditorSheet(
                            context,
                            provider: provider,
                            initialKind: provider.kind,
                            lastKnownOllamaEndpoint:
                                onboardingState?.lastOllamaEndpoint,
                          );
                        },
                        onRefreshHealth: () async {
                          await ref
                              .read(providerManagementProvider.notifier)
                              .refreshProviderHealth(provider.id, force: true);
                        },
                        onDelete: () async {
                          await _deleteProvider(
                            context,
                            ref,
                            provider,
                            providers,
                          );
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    '$error',
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

  Future<void> _deleteProvider(
    BuildContext context,
    WidgetRef ref,
    Provider provider,
    List<Provider> providers,
  ) async {
    final notifier = ref.read(providerManagementProvider.notifier);
    final usageCount = await notifier.getConversationUsageCount(provider.id);
    if (!context.mounted) {
      return;
    }

    final fallbackDecision = await showDialog<_DeleteProviderDecision>(
      context: context,
      builder: (dialogContext) => _DeleteProviderDialog(
        provider: provider,
        usageCount: usageCount,
        fallbackCandidates: providers
            .where((candidate) => candidate.id != provider.id)
            .toList(),
      ),
    );

    if (fallbackDecision == null) {
      return;
    }

    await notifier.deleteProviderWithFallback(
      provider.id,
      fallbackProviderId: fallbackDecision.fallbackProviderId,
      fallbackModelId: fallbackDecision.fallbackModelId,
    );
    ref.invalidate(onboardingProvider);
    ref.invalidate(chatStateProvider);
    ref.invalidate(conversationListProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${provider.displayName}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await notifier.restoreProvider(provider.id);
            ref.invalidate(onboardingProvider);
            ref.invalidate(chatStateProvider);
            ref.invalidate(conversationListProvider);
          },
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  static final DateFormat _dateFormat = DateFormat('MMM d · HH:mm');

  final Provider provider;
  final Future<void> Function() onEdit;
  final Future<void> Function() onRefreshHealth;
  final Future<void> Function() onDelete;

  const _ProviderCard({
    required this.provider,
    required this.onEdit,
    required this.onRefreshHealth,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endpointType = _classifyEndpoint(provider.baseUrl);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        provider.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.kind == ProviderKind.ollama
                            ? 'Ollama'
                            : 'OpenAI-compatible',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5F4634),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_ProviderAction>(
                  itemBuilder: (context) => <PopupMenuEntry<_ProviderAction>>[
                    const PopupMenuItem<_ProviderAction>(
                      value: _ProviderAction.edit,
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem<_ProviderAction>(
                      value: _ProviderAction.refreshHealth,
                      child: Text('Refresh health'),
                    ),
                    const PopupMenuItem<_ProviderAction>(
                      value: _ProviderAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                  onSelected: (action) async {
                    switch (action) {
                      case _ProviderAction.edit:
                        await onEdit();
                        break;
                      case _ProviderAction.refreshHealth:
                        await onRefreshHealth();
                        break;
                      case _ProviderAction.delete:
                        await onDelete();
                        break;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(
                  icon: _healthIcon(provider.healthStatus),
                  label: _healthLabel(provider.healthStatus),
                ),
                _InfoChip(
                  icon: Icons.route_rounded,
                  label: endpointType,
                ),
                _InfoChip(
                  icon: Icons.tune_rounded,
                  label: provider.defaultModelId ?? 'No default model',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _healthDescription(provider.healthStatus),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5F4634),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F1EA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    provider.baseUrl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.healthCheckedAt == null
                        ? 'Never health checked'
                        : 'Last checked ${_dateFormat.format(provider.healthCheckedAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5F4634),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProviderManagementState extends StatelessWidget {
  final Future<void> Function() onAddProvider;

  const _EmptyProviderManagementState({
    required this.onAddProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.hub_outlined, size: 44),
                  const SizedBox(height: 16),
                  Text(
                    'No providers configured',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Add an Ollama or OpenAI-compatible provider to start sending messages.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF5F4634),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      onAddProvider();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add provider'),
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

class _DeleteProviderDialog extends StatefulWidget {
  final Provider provider;
  final int usageCount;
  final List<Provider> fallbackCandidates;

  const _DeleteProviderDialog({
    required this.provider,
    required this.usageCount,
    required this.fallbackCandidates,
  });

  @override
  State<_DeleteProviderDialog> createState() => _DeleteProviderDialogState();
}

class _DeleteProviderDialogState extends State<_DeleteProviderDialog> {
  String? _fallbackProviderId;

  @override
  void initState() {
    super.initState();
    _fallbackProviderId = widget.fallbackCandidates.isEmpty
        ? null
        : widget.fallbackCandidates.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Delete ${widget.provider.displayName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.usageCount == 0
                ? 'This provider will be soft deleted. You can restore it from Undo immediately after deletion.'
                : 'This provider is still selected by ${widget.usageCount} conversation${widget.usageCount == 1 ? '' : 's'}. Choose how those conversations should behave after deletion.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          if (widget.usageCount > 0) ...<Widget>[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _fallbackProviderId,
              decoration: const InputDecoration(
                labelText: 'Fallback provider',
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Clear provider selection'),
                ),
                ...widget.fallbackCandidates.map(
                  (provider) => DropdownMenuItem<String?>(
                    value: provider.id,
                    child: Text(
                      '${provider.displayName}${provider.defaultModelId != null ? ' · ${provider.defaultModelId}' : ''}',
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _fallbackProviderId = value;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              _fallbackProviderId == null
                  ? 'Affected conversations will keep their history but clear the selected provider and model.'
                  : 'Affected conversations will switch to the selected fallback provider and its default model.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5F4634),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final fallbackProvider = widget.fallbackCandidates.cast<Provider?>()
                .firstWhere(
                  (provider) => provider?.id == _fallbackProviderId,
                  orElse: () => null,
                );
            Navigator.of(context).pop(
              _DeleteProviderDecision(
                fallbackProviderId: fallbackProvider?.id,
                fallbackModelId: fallbackProvider?.defaultModelId,
              ),
            );
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _DeleteProviderDecision {
  final String? fallbackProviderId;
  final String? fallbackModelId;

  const _DeleteProviderDecision({
    required this.fallbackProviderId,
    required this.fallbackModelId,
  });
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

enum _ProviderAction { edit, refreshHealth, delete }

String _classifyEndpoint(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  final host = uri?.host.toLowerCase() ?? '';

  if (host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '[::1]') {
    return 'Local endpoint';
  }

  if (host.endsWith('.local') ||
      host.startsWith('192.168.') ||
      host.startsWith('10.') ||
      host.startsWith('172.16.') ||
      host.startsWith('172.17.') ||
      host.startsWith('172.18.') ||
      host.startsWith('172.19.') ||
      host.startsWith('172.20.') ||
      host.startsWith('172.21.') ||
      host.startsWith('172.22.') ||
      host.startsWith('172.23.') ||
      host.startsWith('172.24.') ||
      host.startsWith('172.25.') ||
      host.startsWith('172.26.') ||
      host.startsWith('172.27.') ||
      host.startsWith('172.28.') ||
      host.startsWith('172.29.') ||
      host.startsWith('172.30.') ||
      host.startsWith('172.31.')) {
    return 'LAN endpoint';
  }

  return 'Remote endpoint';
}

String _healthLabel(ProviderHealthStatus? status) {
  switch (status) {
    case ProviderHealthStatus.healthy:
      return 'Healthy';
    case ProviderHealthStatus.degraded:
      return 'Degraded';
    case ProviderHealthStatus.unreachable:
      return 'Unreachable';
    case ProviderHealthStatus.neverChecked:
    case null:
      return 'Never checked';
  }
}

String _healthDescription(ProviderHealthStatus? status) {
  switch (status) {
    case ProviderHealthStatus.healthy:
      return 'The provider responded successfully and is ready for the next request.';
    case ProviderHealthStatus.degraded:
      return 'The provider responded with a warning state such as authentication or configuration trouble.';
    case ProviderHealthStatus.unreachable:
      return 'The provider did not answer within the health-check window.';
    case ProviderHealthStatus.neverChecked:
    case null:
      return 'Run a health refresh to verify this provider before using it.';
  }
}

IconData _healthIcon(ProviderHealthStatus? status) {
  switch (status) {
    case ProviderHealthStatus.healthy:
      return Icons.check_circle_outline_rounded;
    case ProviderHealthStatus.degraded:
      return Icons.error_outline_rounded;
    case ProviderHealthStatus.unreachable:
      return Icons.wifi_off_rounded;
    case ProviderHealthStatus.neverChecked:
    case null:
      return Icons.help_outline_rounded;
  }
}
