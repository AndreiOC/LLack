import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../app/providers/providers.dart';
import '../../domain/entities/entities.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _manualModelController = TextEditingController();

  int _stepIndex = 0;
  bool _didHydrate = false;
  bool _localOnlyMode = true;
  bool _isValidating = false;
  bool _isLoadingModels = false;
  bool _isSaving = false;
  ProviderKind _selectedKind = ProviderKind.ollama;
  List<ProviderModel> _availableModels = const <ProviderModel>[];
  String? _selectedModelId;
  String? _statusMessage;
  bool _lastValidationSucceeded = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _manualModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onboardingAsync = ref.watch(onboardingProvider);
    final discoveryState = ref.watch(ollamaDiscoveryProvider);
    final onboardingState = onboardingAsync.valueOrNull;

    if (!_didHydrate && onboardingState != null) {
      _didHydrate = true;
      _localOnlyMode = onboardingState.localOnlyMode;
      _applyKindDefaults(onboardingState.lastOllamaEndpoint);
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
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
                          _FlowHeader(stepIndex: _stepIndex),
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _stepIndex == 0
                                ? _buildWelcomeStep(theme)
                                : _buildProviderStep(
                                    theme,
                                    discoveryState,
                                    onboardingState,
                                  ),
                          ),
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

  Widget _buildWelcomeStep(ThemeData theme) {
    return Column(
      key: const ValueKey<String>('welcome-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _HeroBadge(label: 'Local-first chat stack'),
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
          'FOSS Chat stores provider metadata in SQLite, keeps API keys in secure storage, and gives Ollama plus OpenAI-compatible backends the same conversation UI.',
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
              title: 'Private by default',
              body:
                  'Stay local with Ollama, or bring your own hosted endpoint only when you need it.',
              icon: Icons.lock_outline,
            ),
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
          ],
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 680;
            final children = <Widget>[
              Expanded(
                child: _ChoiceCard(
                  title: 'Start with Ollama',
                  subtitle:
                      'Use a local endpoint and let the app scan common hosts for you.',
                  accent: const Color(0xFFB85C38),
                  icon: Icons.memory_rounded,
                  actionLabel: 'Use Ollama',
                  onPressed: () => _goToProviderStep(ProviderKind.ollama),
                ),
              ),
              Expanded(
                child: _ChoiceCard(
                  title: 'Use an API provider',
                  subtitle:
                      'Connect any OpenAI-compatible base URL with a secure API key.',
                  accent: const Color(0xFF264653),
                  icon: Icons.cloud_queue_rounded,
                  actionLabel: 'Use API Provider',
                  onPressed: () =>
                      _goToProviderStep(ProviderKind.openaiCompatible),
                ),
              ),
            ];

            if (isNarrow) {
              return Column(
                children: <Widget>[
                  children.first,
                  const SizedBox(height: 16),
                  children.last,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                children.first,
                const SizedBox(width: 16),
                children.last,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProviderStep(
    ThemeData theme,
    OllamaDiscoveryState discoveryState,
    OnboardingState? onboardingState,
  ) {
    final hasLoadedModels = _availableModels.isNotEmpty;
    final ollamaEndpoint = onboardingState?.lastOllamaEndpoint;

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey<String>('provider-step'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton.filledTonal(
                onPressed: () => setState(() {
                  _stepIndex = 0;
                }),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Provider setup',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF2B1D12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configure the provider you want to use first. You can add more later without changing the conversation flow.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5F4634),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SegmentedButton<ProviderKind>(
            selected: <ProviderKind>{_selectedKind},
            showSelectedIcon: false,
            segments: const <ButtonSegment<ProviderKind>>[
              ButtonSegment<ProviderKind>(
                value: ProviderKind.ollama,
                label: Text('Ollama'),
                icon: Icon(Icons.memory_rounded),
              ),
              ButtonSegment<ProviderKind>(
                value: ProviderKind.openaiCompatible,
                label: Text('OpenAI-compatible'),
                icon: Icon(Icons.cloud_queue_rounded),
              ),
            ],
            onSelectionChanged: (selection) {
              final nextKind = selection.first;
              setState(() {
                _selectedKind = nextKind;
                _statusMessage = null;
                _lastValidationSucceeded = false;
                _availableModels = const <ProviderModel>[];
                _selectedModelId = null;
                _manualModelController.clear();
                _applyKindDefaults(ollamaEndpoint);
                if (nextKind == ProviderKind.ollama) {
                  _localOnlyMode = true;
                } else {
                  _localOnlyMode = false;
                }
              });
            },
          ),
          const SizedBox(height: 20),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prefer local-only mode'),
            subtitle: const Text(
              'Hide cloud-provider nudges and keep the onboarding focused on local inference.',
            ),
            value: _localOnlyMode,
            onChanged: (value) {
              setState(() {
                _localOnlyMode = value;
              });
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 760;
              final formColumn = Expanded(
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller: _displayNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        hintText: 'Local Ollama',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a provider name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _baseUrlController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _selectedKind == ProviderKind.ollama
                            ? 'Ollama endpoint'
                            : 'Base URL',
                        hintText: _selectedKind == ProviderKind.ollama
                            ? 'http://127.0.0.1:11434'
                            : 'https://api.openai.com/v1',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a base URL.';
                        }
                        final normalized = _normalizeEndpoint(value);
                        final parsed = Uri.tryParse(normalized);
                        if (parsed == null ||
                            !parsed.hasScheme ||
                            parsed.host.isEmpty) {
                          return 'Enter a valid URL.';
                        }
                        return null;
                      },
                    ),
                    if (_selectedKind ==
                        ProviderKind.openaiCompatible) ...<Widget>[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _apiKeyController,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'API key',
                          hintText: 'sk-...',
                        ),
                        validator: (value) {
                          if (_selectedKind == ProviderKind.openaiCompatible &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Enter an API key.';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (hasLoadedModels)
                      DropdownButtonFormField<String>(
                        value: _selectedModelId,
                        items: _availableModels
                            .map(
                              (model) => DropdownMenuItem<String>(
                                value: model.remoteModelId,
                                child: Text(model.displayName),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'Default model',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedModelId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Choose a default model.';
                          }
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: _manualModelController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Default model',
                          hintText: 'llama3.1:8b or gpt-4o-mini',
                        ),
                        validator: (value) {
                          if (!hasLoadedModels &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Enter a default model id.';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F1EA),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.security_rounded,
                              color: Color(0xFF7B4A2E)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedKind == ProviderKind.ollama
                                  ? 'Metadata is stored locally. For Ollama, there is no API key to manage unless you front it with a proxy.'
                                  : 'Provider metadata stays in SQLite. Your API key is stored separately using the platform secure-storage backend.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF5F4634),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final discoveryColumn = Expanded(
                child: _selectedKind == ProviderKind.ollama
                    ? _DiscoveryPanel(
                        state: discoveryState,
                        lastKnownEndpoint: ollamaEndpoint,
                        selectedEndpoint: _baseUrlController.text.trim(),
                        onScan: () {
                          ref
                              .read(ollamaDiscoveryProvider.notifier)
                              .scan(lastKnownEndpoint: ollamaEndpoint);
                        },
                        onUseCandidate: _applyCandidate,
                      )
                    : _CloudSetupPanel(
                        onPrefillOpenAi: () {
                          setState(() {
                            if (_displayNameController.text.trim().isEmpty ||
                                _displayNameController.text.trim() ==
                                    'API Provider') {
                              _displayNameController.text = 'OpenAI';
                            }
                            _baseUrlController.text =
                                'https://api.openai.com/v1';
                            _statusMessage = null;
                          });
                        },
                      ),
              );

              if (isNarrow) {
                return Column(
                  children: <Widget>[
                    formColumn,
                    const SizedBox(height: 20),
                    discoveryColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  formColumn,
                  const SizedBox(width: 20),
                  discoveryColumn,
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _isValidating ? null : _validateProvider,
                icon: _isValidating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.health_and_safety_outlined),
                label: const Text('Test connection'),
              ),
              OutlinedButton.icon(
                onPressed: _isLoadingModels ? null : _loadModels,
                icon: _isLoadingModels
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.dataset_outlined),
                label: const Text('Fetch models'),
              ),
              FilledButton.tonalIcon(
                onPressed: _isSaving ? null : _saveProvider,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: const Text('Finish setup'),
              ),
            ],
          ),
          if (_statusMessage != null) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _lastValidationSucceeded
                    ? const Color(0xFFE6F4EA)
                    : const Color(0xFFFCE8E6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _lastValidationSucceeded
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: _lastValidationSucceeded
                        ? const Color(0xFF2D6A4F)
                        : const Color(0xFF9C2F2F),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _lastValidationSucceeded
                            ? const Color(0xFF2D6A4F)
                            : const Color(0xFF9C2F2F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _goToProviderStep(ProviderKind kind) {
    setState(() {
      _stepIndex = 1;
      _selectedKind = kind;
      _availableModels = const <ProviderModel>[];
      _selectedModelId = null;
      _manualModelController.clear();
      _statusMessage = null;
      _lastValidationSucceeded = false;
      if (kind == ProviderKind.ollama) {
        _localOnlyMode = true;
      }
      _applyKindDefaults(
          ref.read(onboardingProvider).valueOrNull?.lastOllamaEndpoint);
    });
  }

  void _applyKindDefaults(String? lastOllamaEndpoint) {
    final defaultName =
        _selectedKind == ProviderKind.ollama ? 'Local Ollama' : 'API Provider';
    final currentName = _displayNameController.text.trim();
    if (currentName.isEmpty ||
        currentName == 'Local Ollama' ||
        currentName == 'API Provider' ||
        currentName == 'OpenAI') {
      _displayNameController.text = defaultName;
    }

    final currentBaseUrl = _baseUrlController.text.trim();
    if (_selectedKind == ProviderKind.ollama) {
      if (currentBaseUrl.isEmpty ||
          currentBaseUrl == 'https://api.openai.com/v1') {
        _baseUrlController.text = lastOllamaEndpoint?.trim().isNotEmpty == true
            ? lastOllamaEndpoint!.trim()
            : 'http://127.0.0.1:11434';
      }
      _apiKeyController.clear();
    } else if (currentBaseUrl.isEmpty ||
        currentBaseUrl == 'http://127.0.0.1:11434' ||
        currentBaseUrl == 'http://localhost:11434' ||
        currentBaseUrl == (lastOllamaEndpoint ?? '')) {
      _baseUrlController.text = 'https://api.openai.com/v1';
    }
  }

  Future<void> _validateProvider() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isValidating = true;
      _statusMessage = null;
    });

    try {
      final result =
          await ref.read(providerManagementProvider.notifier).validateDraft(
                _draftProvider(),
                apiKey: _apiKeyValue,
              );
      if (!mounted) {
        return;
      }

      setState(() {
        _lastValidationSucceeded = result.isValid;
        _statusMessage = result.isValid
            ? 'Connection succeeded.'
            : (result.errorMessage ?? 'Validation failed.');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastValidationSucceeded = false;
        _statusMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  Future<void> _loadModels() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoadingModels = true;
      _statusMessage = null;
    });

    try {
      final models = await ref
          .read(providerManagementProvider.notifier)
          .fetchModelsForDraft(
            _draftProvider(),
            apiKey: _apiKeyValue,
          );
      if (!mounted) {
        return;
      }

      setState(() {
        _availableModels = models;
        _selectedModelId =
            models.isNotEmpty ? models.first.remoteModelId : null;
        _lastValidationSucceeded = models.isNotEmpty;
        _statusMessage = models.isEmpty
            ? 'The provider responded, but it did not return any models.'
            : 'Loaded ${models.length} model${models.length == 1 ? '' : 's'}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lastValidationSucceeded = false;
        _statusMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingModels = false;
        });
      }
    }
  }

  Future<void> _saveProvider() async {
    if (!_validateForm()) {
      return;
    }

    final defaultModelId = _resolvedModelId;
    if (defaultModelId == null || defaultModelId.isEmpty) {
      setState(() {
        _lastValidationSucceeded = false;
        _statusMessage = 'Choose a default model before finishing setup.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final provider =
          _draftProvider().copyWith(defaultModelId: defaultModelId);
      await ref.read(providerManagementProvider.notifier).addProvider(
            provider,
            apiKey: _apiKeyValue,
          );
      await ref.read(onboardingProvider.notifier).complete(
            localOnlyMode: _localOnlyMode,
            lastOllamaEndpoint:
                _selectedKind == ProviderKind.ollama ? provider.baseUrl : null,
          );
      ref.invalidate(chatStateProvider);
      ref.invalidate(conversationListProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lastValidationSucceeded = false;
        _statusMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _applyCandidate(OllamaEndpointCandidate candidate) {
    setState(() {
      _selectedKind = ProviderKind.ollama;
      if (_displayNameController.text.trim().isEmpty ||
          _displayNameController.text.trim() == 'Local Ollama' ||
          _displayNameController.text.trim() == 'API Provider') {
        _displayNameController.text = candidate.label;
      }
      _baseUrlController.text = candidate.endpoint;
      _statusMessage = candidate.detail;
      _lastValidationSucceeded = candidate.isReachable;
    });
  }

  bool _validateForm() {
    return _formKey.currentState?.validate() ?? false;
  }

  Provider _draftProvider() {
    final now = DateTime.now();
    return Provider(
      id: 'draft-provider',
      kind: _selectedKind,
      displayName: _displayNameController.text.trim(),
      baseUrl: _normalizeEndpoint(_baseUrlController.text),
      defaultModelId: _resolvedModelId,
      headers: const <String, String>{},
      settings: const <String, dynamic>{},
      healthStatus: ProviderHealthStatus.neverChecked,
      createdAt: now,
      updatedAt: now,
    );
  }

  String? get _apiKeyValue {
    final trimmed = _apiKeyController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? get _resolvedModelId {
    if (_selectedModelId != null && _selectedModelId!.trim().isNotEmpty) {
      return _selectedModelId!.trim();
    }
    final trimmed = _manualModelController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeEndpoint(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'http://$trimmed';
  }
}

class _FlowHeader extends StatelessWidget {
  final int stepIndex;

  const _FlowHeader({required this.stepIndex});

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
          children: List<Widget>.generate(2, (index) {
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
  final VoidCallback onPressed;

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

class _DiscoveryPanel extends StatelessWidget {
  final OllamaDiscoveryState state;
  final String? lastKnownEndpoint;
  final String selectedEndpoint;
  final VoidCallback onScan;
  final ValueChanged<OllamaEndpointCandidate> onUseCandidate;

  const _DiscoveryPanel({
    required this.state,
    required this.lastKnownEndpoint,
    required this.selectedEndpoint,
    required this.onScan,
    required this.onUseCandidate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCandidates = state.candidates.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.radar_rounded, color: Color(0xFF7B4A2E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ollama discovery',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2B1D12),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: state.isScanning ? null : onScan,
                  icon: state.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  label: const Text('Scan'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'The scan probes common local endpoints and listens briefly for `_ollama._tcp` Bonjour broadcasts.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5F4634),
                height: 1.45,
              ),
            ),
            if (lastKnownEndpoint != null &&
                lastKnownEndpoint!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  const Chip(
                    label: Text('Saved endpoint'),
                    avatar: Icon(Icons.history_rounded, size: 18),
                  ),
                  ActionChip(
                    label: Text(lastKnownEndpoint!),
                    onPressed: () {
                      onUseCandidate(
                        OllamaEndpointCandidate(
                          label: 'Last successful endpoint',
                          endpoint: lastKnownEndpoint!,
                          source: 'Saved',
                          isReachable: true,
                          modelCount: null,
                          detail: 'Saved from a previous successful session.',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9C2F2F),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (!hasCandidates && !state.isScanning)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'No scan results yet. Use the manual endpoint field or run a scan.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5F4634),
                  ),
                ),
              ),
            if (hasCandidates)
              ...state.candidates.map(
                (candidate) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: candidate.endpoint == selectedEndpoint
                            ? const Color(0xFFB85C38)
                            : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Icon(
                        candidate.isReachable
                            ? Icons.check_circle_outline_rounded
                            : Icons.wifi_off_rounded,
                        color: candidate.isReachable
                            ? const Color(0xFF2D6A4F)
                            : const Color(0xFF9C2F2F),
                      ),
                      title: Text(candidate.label),
                      subtitle: Text(
                        '${candidate.endpoint}\n${candidate.source}${candidate.detail != null ? ' · ${candidate.detail}' : ''}',
                      ),
                      trailing: TextButton(
                        onPressed: () => onUseCandidate(candidate),
                        child: const Text('Use'),
                      ),
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

class _CloudSetupPanel extends StatelessWidget {
  final VoidCallback onPrefillOpenAi;

  const _CloudSetupPanel({required this.onPrefillOpenAi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.cloud_queue_rounded, color: Color(0xFF264653)),
                const SizedBox(width: 10),
                Text(
                  'API-compatible setup',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF17313A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Use this path for OpenAI-compatible endpoints such as OpenAI, OpenRouter, Groq, or self-hosted gateways that expose `/models` and `/chat/completions`.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF36525A),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Quick start',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Prefill the standard OpenAI base URL, then test the connection and fetch models to choose a default.',
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: onPrefillOpenAi,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('Use OpenAI defaults'),
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
