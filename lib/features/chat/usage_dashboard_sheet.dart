import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers/providers.dart';
import '../../data/services/usage_service.dart';

class UsageDashboardSheet extends ConsumerStatefulWidget {
  const UsageDashboardSheet({super.key});

  @override
  ConsumerState<UsageDashboardSheet> createState() =>
      _UsageDashboardSheetState();
}

class _UsageDashboardSheetState extends ConsumerState<UsageDashboardSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overviewAsync = ref.watch(usageOverviewProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: overviewAsync.when(
          data: (overview) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Usage dashboard',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Daily, weekly, and monthly token activity from the local database.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B5A4A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (overview.monthlyThresholdDollars != null)
                    _ThresholdCard(
                      state: overview.thresholdState,
                      monthlySpend: overview.monthlyCloud.estimatedCostDollars,
                      threshold: overview.monthlyThresholdDollars!,
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _StatCard(
                        label: 'Today',
                        totals: overview.daily,
                        accent: const Color(0xFFB85C38),
                      ),
                      _StatCard(
                        label: 'This week',
                        totals: overview.weekly,
                        accent: const Color(0xFF264653),
                      ),
                      _StatCard(
                        label: 'This month',
                        totals: overview.monthly,
                        accent: const Color(0xFF3A6B35),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _SegmentCard(
                          label: 'Local',
                          subtitle: 'Ollama and other offline runs',
                          totals: overview.monthlyLocal,
                          tint: const Color(0xFFE9C46A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SegmentCard(
                          label: 'Cloud',
                          subtitle: 'Metered remote usage',
                          totals: overview.monthlyCloud,
                          tint: const Color(0xFFE76F51),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Providers',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editThreshold(overview),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(
                          overview.monthlyThresholdDollars == null
                              ? 'Set threshold'
                              : 'Edit threshold',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (overview.providerBreakdown.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F1E8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text('No usage recorded yet.'),
                    )
                  else
                    ...overview.providerBreakdown.map(
                      (providerUsage) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ProviderUsageTile(providerUsage: providerUsage),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 240,
            child: Center(
              child: Text(
                '$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editThreshold(UsageOverview overview) async {
    final controller = TextEditingController(
      text: overview.monthlyThresholdDollars?.toStringAsFixed(2) ?? '',
    );
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Monthly spend threshold'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'USD amount',
              hintText: 'e.g. 25.00',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final raw = controller.text.trim();
                final value = raw.isEmpty ? null : double.tryParse(raw);
                if (raw.isNotEmpty && value == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid dollar amount.'),
                    ),
                  );
                  return;
                }

                final usageService =
                    await ref.read(usageServiceProvider.future);
                await usageService.setMonthlySpendThresholdDollars(value);
                ref.invalidate(usageOverviewProvider);
                if (!mounted) {
                  return;
                }
                Navigator.of(this.context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  final UsageThresholdState state;
  final double monthlySpend;
  final double threshold;

  const _ThresholdCard({
    required this.state,
    required this.monthlySpend,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground, copy) = switch (state) {
      UsageThresholdState.exceeded => (
          const Color(0xFFFBE4DF),
          const Color(0xFF8C3D3D),
          'Monthly cloud spend has exceeded the configured threshold.',
        ),
      UsageThresholdState.approaching => (
          const Color(0xFFF9EDD0),
          const Color(0xFF8A5A13),
          'Monthly cloud spend is approaching the configured threshold.',
        ),
      UsageThresholdState.none => (
          const Color(0xFFEAF5EA),
          const Color(0xFF315A31),
          'Monthly cloud spend is below the configured threshold.',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cloud spend: ${_currency(monthlySpend)} / Threshold: ${_currency(threshold)}',
            style: TextStyle(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final UsageMetric totals;
  final Color accent;

  const _StatCard({
    required this.label,
    required this.totals,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B5A4A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _tokenCount(totals.totalTokens),
            style: TextStyle(
              color: accent,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'In ${_tokenCount(totals.inputTokens)} · Out ${_tokenCount(totals.outputTokens)}',
            style: const TextStyle(color: Color(0xFF6B5A4A)),
          ),
          const SizedBox(height: 8),
          Text(
            _currency(totals.estimatedCostDollars),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final UsageMetric totals;
  final Color tint;

  const _SegmentCard({
    required this.label,
    required this.subtitle,
    required this.totals,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6B5A4A)),
          ),
          const SizedBox(height: 10),
          Text(
            _tokenCount(totals.totalTokens),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: tint.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(_currency(totals.estimatedCostDollars)),
        ],
      ),
    );
  }
}

class _ProviderUsageTile extends StatelessWidget {
  final ProviderUsageMetric providerUsage;

  const _ProviderUsageTile({required this.providerUsage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6D7C8)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: providerUsage.isLocal
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
                  providerUsage.providerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  providerUsage.isLocal ? 'Local provider' : 'Cloud provider',
                  style: const TextStyle(color: Color(0xFF6B5A4A)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _tokenCount(providerUsage.totals.totalTokens),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(_currency(providerUsage.totals.estimatedCostDollars)),
            ],
          ),
        ],
      ),
    );
  }
}

final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');
final NumberFormat _compactNumberFormat = NumberFormat.compact();

String _currency(double value) {
  return _currencyFormat.format(value);
}

String _tokenCount(int value) {
  return '${_compactNumberFormat.format(value)} tok';
}
