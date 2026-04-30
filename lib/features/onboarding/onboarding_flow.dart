import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers/providers.dart';
import '../../domain/entities/entities.dart';
import '../providers/provider_editor_sheet.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const String _draftPageKey = 'onboarding_draft_page';

  final PageController _pageController = PageController();
  int _pageIndex = 0;
  bool _isCompleting = false;
  bool _didHydrate = false;
  bool _preferLocalOnlyMode = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onboardingState = ref.watch(onboardingProvider).valueOrNull;

    if (!_didHydrate && onboardingState != null) {
      _didHydrate = true;
      _preferLocalOnlyMode = onboardingState.localOnlyMode;
      _restoreDraftPage();
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFFF8F1E7),
            Color(0xFFF2E3D5),
            Color(0xFFE7D7C4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x221B120A),
                          blurRadius: 40,
                          offset: Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _FlowHeader(
                            stepIndex: _pageIndex,
                            onSkip: _pageIndex < 2
                                ? () => _goToPage(2)
                                : null,
                          ),
                          const SizedBox(height: 28),
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: _handlePageChanged,
                              children: <Widget>[
                                _buildValuePage(theme),
                                _buildPrivacyPage(theme),
                                _buildSetupPage(theme, onboardingState),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildFooterActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildValuePage(ThemeData theme) {
    return ListView(
      children: <Widget>[
        const _HeroBadge(label: 'Product value'),
        const SizedBox(height: 18),
        Text(
          'Bring your models online without surrendering the app.',
          style: theme.textTheme.displaySmall?.copyWith(
            color: const Color(0xFF2B1D12),
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'FOSS Chat keeps local and hosted providers in the same conversation workflow so you can start with Ollama now and add cloud capacity later without switching tools.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF5F4634),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _FeatureCard(
              title: 'One chat surface',
              body:
                  'Switch providers without rebuilding your workflow around another app.',
              icon: Icons.forum_outlined,
            ),
            _FeatureCard(
              title: 'Streaming responses',
              body:
                  'See assistant output appear token by token instead of waiting for a full block.',
              icon: Icons.graphic_eq_rounded,
            ),
            _FeatureCard(
              title: 'Durable local history',
              body:
                  'Messages and conversations persist locally so the thread is still there when you come back.',
              icon: Icons.history_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacyPage(ThemeData theme) {
    return ListView(
      children: <Widget>[
        const _HeroBadge(label: 'Privacy and local-first'),
        const SizedBox(height: 18),
        Text(
          'Keep the app private by default, then opt into remote providers deliberately.',
          style: theme.textTheme.displaySmall?.copyWith(
            color: const Color(0xFF2B1D12),
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Spec FR-ONB-2 and the security section require API keys to stay in secure storage while provider metadata lives in SQLite. Local-only mode keeps the onboarding and the rest of the app biased toward Ollama-first paths.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF5F4634),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _FeatureCard(
              title: 'Secure key handling',
              body:
                  'API keys are masked in the form, stored in platform secure storage, and never written into SQLite.',
              icon: Icons.lock_outline,
            ),
            _FeatureCard(
              title: 'Local-only mode',
              body:
                  'Suppress cloud-provider nudges and keep the app centered on local inference when that is the right fit.',
              icon: Icons.memory_rounded,
            ),
            _FeatureCard(
              title: 'Manual fallback',
              body:
                  'Ollama discovery is helpful, but manual endpoint entry remains available when scans fail.',
              icon: Icons.route_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSetupPage(
    ThemeData theme,
    OnboardingState? onboardingState,
  ) {
    return ListView(
      children: <Widget>[
        const _HeroBadge(label: 'Setup choices'),
        const SizedBox(height: 18),
        Text(
          'Choose how you want to start.',
          style: theme.textTheme.displaySmall?.copyWith(
            color: const Color(0xFF2B1D12),
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Spec FR-ONB-1 and FR-ONB-4 require a real setup choice, a skip path, and a persistent local-only option rather than a single forced provider flow.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF5F4634),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Prefer local-only mode after setup'),
          subtitle: const Text(
            'Suppress cloud-provider nudges and keep future add-provider flows biased toward Ollama.',
          ),
          value: _preferLocalOnlyMode,
          onChanged: (value) {
            setState(() {
              _preferLocalOnlyMode = value;
            });
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 760;
            final ollamaCard = _ChoiceCard(
              title: 'Start with Ollama',
              subtitle:
                  'Open the shared provider editor with Ollama-first defaults and optional LAN discovery.',
              accent: const Color(0xFFB85C38),
              icon: Icons.memory_rounded,
              actionLabel: 'Configure Ollama',
              onPressed: _isCompleting
                  ? null
                  : () => _configureProvider(
                        ProviderKind.ollama,
                        localOnlyMode: _preferLocalOnlyMode,
                        lastOllamaEndpoint:
                            onboardingState?.lastOllamaEndpoint,
                      ),
            );
            final apiCard = _ChoiceCard(
              title: 'Use an API provider',
              subtitle:
                  'Connect an OpenAI-compatible base URL with secure API-key storage and model selection.',
              accent: const Color(0xFF264653),
              icon: Icons.cloud_queue_rounded,
              actionLabel: 'Configure API Provider',
              onPressed: _isCompleting
                  ? null
                  : () => _configureProvider(
                        ProviderKind.openaiCompatible,
                        localOnlyMode: false,
                        lastOllamaEndpoint:
                            onboardingState?.lastOllamaEndpoint,
                      ),
            );

            if (isNarrow) {
              return Column(
                children: <Widget>[
                  ollamaCard,
                  const SizedBox(height: 16),
                  apiCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: ollamaCard),
                const SizedBox(width: 16),
                Expanded(child: apiCard),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F1EA),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.offline_bolt_rounded,
                    color: Color(0xFF7B4A2E)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Local only for now',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2B1D12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete onboarding without adding a provider yet. The app will open to the main shell, keep `skip_cloud_providers = true`, and let you add Ollama later from provider management.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5F4634),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: _isCompleting ? null : _completeLocalOnly,
                        icon: _isCompleting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Enter the app'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterActions() {
    if (_pageIndex == 2) {
      return Row(
        children: <Widget>[
          OutlinedButton(
            onPressed: _isCompleting ? null : () => _goToPage(1),
            child: const Text('Back'),
          ),
          const Spacer(),
          TextButton(
            onPressed: _isCompleting ? null : _completeLocalOnly,
            child: const Text('Skip setup'),
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        if (_pageIndex > 0)
          OutlinedButton(
            onPressed: _isCompleting ? null : () => _goToPage(_pageIndex - 1),
            child: const Text('Back'),
          ),
        if (_pageIndex > 0) const SizedBox(width: 12),
        if (_pageIndex == 0)
          TextButton(
            onPressed: _isCompleting ? null : () => _goToPage(2),
            child: const Text('Skip to setup'),
          ),
        const Spacer(),
        FilledButton(
          onPressed: _isCompleting ? null : () => _goToPage(_pageIndex + 1),
          child: const Text('Next'),
        ),
      ],
    );
  }

  Future<void> _configureProvider(
    ProviderKind kind, {
    required bool localOnlyMode,
    String? lastOllamaEndpoint,
  }) async {
    setState(() {
      _isCompleting = true;
    });

    try {
      final provider = await showProviderEditorSheet(
        context,
        initialKind: kind,
        lastKnownOllamaEndpoint: lastOllamaEndpoint,
        isOnboarding: true,
      );
      if (provider == null) {
        return;
      }

      await ref.read(onboardingProvider.notifier).complete(
            localOnlyMode: localOnlyMode,
            lastOllamaEndpoint:
                provider.kind == ProviderKind.ollama ? provider.baseUrl : null,
          );
      await _clearDraftPage();
      ref.invalidate(providerManagementProvider);
      ref.invalidate(chatStateProvider);
      ref.invalidate(conversationListProvider);
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  Future<void> _completeLocalOnly() async {
    setState(() {
      _isCompleting = true;
    });

    try {
      final onboardingState = ref.read(onboardingProvider).valueOrNull;
      await ref.read(onboardingProvider.notifier).complete(
            localOnlyMode: true,
            lastOllamaEndpoint: onboardingState?.lastOllamaEndpoint,
          );
      await _clearDraftPage();
      ref.invalidate(chatStateProvider);
      ref.invalidate(conversationListProvider);
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  Future<void> _goToPage(int targetPage) async {
    await _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handlePageChanged(int page) async {
    setState(() {
      _pageIndex = page;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_draftPageKey, page);
  }

  Future<void> _restoreDraftPage() async {
    final prefs = await SharedPreferences.getInstance();
    final page = prefs.getInt(_draftPageKey) ?? 0;
    if (!mounted || page == 0) {
      return;
    }
    final safePage = page.clamp(0, 2).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _pageController.jumpToPage(safePage);
      setState(() {
        _pageIndex = safePage;
      });
    });
  }

  Future<void> _clearDraftPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftPageKey);
  }
}

class _FlowHeader extends StatelessWidget {
  final int stepIndex;
  final VoidCallback? onSkip;

  const _FlowHeader({
    required this.stepIndex,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(
          'FOSS Chat',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2B1D12),
          ),
        ),
        const Spacer(),
        Row(
          children: List<Widget>.generate(3, (index) {
            final isActive = index <= stepIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
              width: index == stepIndex ? 44 : 18,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFB85C38)
                    : const Color(0xFFD4C4B4),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
        if (onSkip != null) ...<Widget>[
          const SizedBox(width: 14),
          TextButton(
            onPressed: onSkip,
            child: const Text('Skip'),
          ),
        ],
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;

  const _HeroBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E1D4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF7B4A2E),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _FeatureCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 264,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF9F3EC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE6D7C8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: const Color(0xFF7B4A2E)),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2B1D12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5F4634),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.14),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 34, color: accent),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2B1D12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF5F4634),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
