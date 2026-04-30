import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/providers.dart';

/// Settings screen for app-wide preferences (spec §10.1).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showLineNumbers = false;
  double? _monthlyThreshold;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final appSettingDao = await ref.read(appSettingDaoProvider.future);
    final lineNumbers = await appSettingDao.getBool('show_code_line_numbers', false);
    final threshold = await appSettingDao.getInt('monthly_spend_threshold');
    if (mounted) {
      setState(() {
        _showLineNumbers = lineNumbers;
        _monthlyThreshold = threshold != null ? threshold / 1000000.0 : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLineNumbers(bool value) async {
    final appSettingDao = await ref.read(appSettingDaoProvider.future);
    await appSettingDao.setBool('show_code_line_numbers', value);
    setState(() => _showLineNumbers = value);
  }

  Future<void> _saveThreshold(double? dollars) async {
    final usageService = await ref.read(usageServiceProvider.future);
    await usageService.setMonthlySpendThresholdDollars(dollars);
    setState(() => _monthlyThreshold = dollars);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  'Appearance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Show code line numbers'),
                  subtitle: const Text('Display line numbers in fenced code blocks'),
                  value: _showLineNumbers,
                  onChanged: _saveLineNumbers,
                ),
                const Divider(height: 32),
                Text(
                  'Usage & Alerts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Monthly spend threshold'),
                  subtitle: Text(_monthlyThreshold != null
                      ? '\$${_monthlyThreshold!.toStringAsFixed(2)}'
                      : 'No threshold set'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editThreshold,
                ),
                const Divider(height: 32),
                Text(
                  'Onboarding',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Replay onboarding'),
                  subtitle: const Text('Show the first-run setup flow again'),
                  leading: const Icon(Icons.replay_outlined),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Replay onboarding?'),
                        content: const Text(
                            'This will show the onboarding flow on the next app launch.'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Replay'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      final scaffoldContext = context;
                      await ref.read(onboardingProvider.notifier).reopen();
                      if (mounted) {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                          const SnackBar(
                              content: Text('Onboarding will replay on next launch.')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
    );
  }

  Future<void> _editThreshold() async {
    final controller = TextEditingController(
      text: _monthlyThreshold?.toStringAsFixed(2) ?? '',
    );
    final result = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly spend threshold'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '\$',
            hintText: 'Leave empty to disable',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                Navigator.pop(context, null);
                return;
              }
              final value = double.tryParse(text);
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != _monthlyThreshold) {
      await _saveThreshold(result);
    }
  }
}
