import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../app/providers/providers.dart';
import '../../domain/entities/entities.dart';

Future<Provider?> showProviderEditorSheet(
  BuildContext context, {
  Provider? provider,
  ProviderKind initialKind = ProviderKind.ollama,
  String? lastKnownOllamaEndpoint,
  bool isOnboarding = false,
}) {
  return showModalBottomSheet<Provider>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: ProviderEditorSheet(
        provider: provider,
        initialKind: initialKind,
        lastKnownOllamaEndpoint: lastKnownOllamaEndpoint,
        isOnboarding: isOnboarding,
      ),
    ),
  );
}

class ProviderEditorSheet extends ConsumerStatefulWidget {
  final Provider? provider;
  final ProviderKind initialKind;
  final String? lastKnownOllamaEndpoint;
  final bool isOnboarding;

  const ProviderEditorSheet({
    super.key,
    this.provider,
    required this.initialKind,
    this.lastKnownOllamaEndpoint,
    this.isOnboarding = false,
  });

  @override
  ConsumerState<ProviderEditorSheet> createState() => _ProviderEditorSheetState();
}

class _ProviderEditorSheetState extends ConsumerState<ProviderEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _manualModelController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _maxTokensController = TextEditingController();
  final TextEditingController _topPController = TextEditingController();
  final List<_HeaderRowController> _headerRows = <_HeaderRowController>[];

  late ProviderKind _selectedKind;
  List<ProviderModel> _availableModels = const <ProviderModel>[];
  String? _selectedModelId;
  String? _statusMessage;
  bool _statusIsSuccess = false;
  bool _obscureApiKey = true;
  bool _isValidating = false;
  bool _isLoadingModels = false;
  bool _isSaving = false;
  bool _hasStoredApiKey = false;
  bool _clearStoredApiKey = false;
  String? _lastValidationFingerprint;

  ProviderConfigurationSchema get _schema =>
      ProviderConfigurationSchemas.forKind(_selectedKind);

  bool get _isEditing => widget.provider != null;

  @override
  void initState() {
    super.initState();
    final provider = widget.provider;
    _selectedKind = provider?.kind ?? widget.initialKind;
    _hasStoredApiKey = provider?.apiKeyRef?.isNotEmpty == true;
    _hydrateFromProvider(provider);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _manualModelController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    _topPController.dispose();
    for (final headerRow in _headerRows) {
      headerRow.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = widget.provider;
    final status = provider?.healthStatus;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
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
                        _isEditing
                            ? 'Edit provider'
                            : (widget.isOnboarding
                                ? 'Configure your first provider'
                                : 'Add provider'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Spec 6.5 and FR-PRV-2: the form is rendered from the provider schema and reused across onboarding and provider management.',
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
            if (provider != null || _statusMessage != null)
              _ProviderStatusBanner(
                status: _statusMessage != null
                    ? null
                    : (status ?? ProviderHealthStatus.neverChecked),
                checkedAt: provider?.healthCheckedAt,
                message: _statusMessage,
                isSuccess: _statusIsSuccess,
              ),
            if (provider != null || _statusMessage != null)
              const SizedBox(height: 16),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: <Widget>[
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
                        if (_selectedKind == nextKind) {
                          return;
                        }
                        setState(() {
                          _selectedKind = nextKind;
                          _availableModels = const <ProviderModel>[];
                          _selectedModelId = null;
                          _manualModelController.clear();
                          _statusMessage = null;
                          _statusIsSuccess = false;
                          _lastValidationFingerprint = null;
                          _clearStoredApiKey = false;
                          _applyKindDefaults();
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // Spec 6.5 and FR-PRV-2: render common controls from the
                    // schema so the same engine supports both provider types.
                    ..._schema.fields.map(_buildField),
                    const SizedBox(height: 16),
                    if (_selectedKind == ProviderKind.ollama)
                      _OllamaHintsPanel(
                        selectedEndpoint: _baseUrlController.text.trim(),
                        lastKnownEndpoint: widget.lastKnownOllamaEndpoint,
                        onUseEndpoint: (endpoint, label) {
                          setState(() {
                            if (_displayNameController.text.trim().isEmpty ||
                                _displayNameController.text.trim() ==
                                    'Local Ollama') {
                              _displayNameController.text = label;
                            }
                            _baseUrlController.text = endpoint;
                            _statusMessage = null;
                            _lastValidationFingerprint = null;
                          });
                        },
                      )
                    else
                      const _OpenAiCompatibleHintsPanel(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isValidating ? null : _validateConnection,
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
                      : const Icon(Icons.save_outlined),
                  label: Text(_isEditing ? 'Save changes' : 'Save provider'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(ProviderFieldSchema field) {
    switch (field.id) {
      case ProviderSchemaFieldIds.displayName:
        return _buildTextField(
          controller: _displayNameController,
          label: field.label,
          helpText: field.helpText,
          validator: (value) {
            if (field.isRequired && (value == null || value.trim().isEmpty)) {
              return 'Enter a provider name.';
            }
            return null;
          },
        );
      case ProviderSchemaFieldIds.baseUrl:
        return _buildTextField(
          controller: _baseUrlController,
          label: field.label,
          helpText: field.helpText,
          keyboardType: TextInputType.url,
          validator: (value) {
            if (field.isRequired && (value == null || value.trim().isEmpty)) {
              return 'Enter a base URL.';
            }
            final normalized = _normalizeEndpoint(value ?? '');
            final parsed = Uri.tryParse(normalized);
            if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
              return 'Enter a valid URL.';
            }
            return null;
          },
        );
      case ProviderSchemaFieldIds.apiKey:
        final requiresApiKey = _selectedKind == ProviderKind.openaiCompatible;
        if (!requiresApiKey) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: field.label,
                hintText: 'sk-...',
                suffixIcon: IconButton(
                  tooltip: _obscureApiKey ? 'Reveal API key' : 'Hide API key',
                  onPressed: () {
                    setState(() {
                      _obscureApiKey = !_obscureApiKey;
                    });
                  },
                  icon: Icon(
                    _obscureApiKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                final keepingStoredKey =
                    _hasStoredApiKey && !_clearStoredApiKey && trimmed.isEmpty;
                if (!keepingStoredKey &&
                    !_clearStoredApiKey &&
                    trimmed.isEmpty) {
                  return 'Enter an API key.';
                }
                if (trimmed.isNotEmpty &&
                    (trimmed.contains(RegExp(r'\s')) || trimmed.length < 6)) {
                  return 'Enter a valid API key format.';
                }
                return null;
              },
            ),
            if (_hasStoredApiKey && _apiKeyController.text.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _clearStoredApiKey
                            ? 'Stored API key will be removed when you save.'
                            : 'An API key is already stored securely. Leave the field empty to keep it, or enter a new value to replace it.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF5F4634),
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _clearStoredApiKey = !_clearStoredApiKey;
                          _statusMessage = null;
                        });
                      },
                      child: Text(_clearStoredApiKey ? 'Keep key' : 'Remove'),
                    ),
                  ],
                ),
              ),
            if (field.helpText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  field.helpText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5F4634),
                      ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      case ProviderSchemaFieldIds.defaultModelId:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_availableModels.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedModelId,
                decoration: InputDecoration(
                  labelText: field.label,
                ),
                items: _availableModels
                    .map(
                      (model) => DropdownMenuItem<String>(
                        value: model.remoteModelId,
                        child: Text(model.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedModelId = value;
                  });
                },
                validator: (value) {
                  if (field.isRequired &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Choose a default model.';
                  }
                  return null;
                },
              )
            else
              _buildTextField(
                controller: _manualModelController,
                label: field.label,
                helpText:
                    'If the provider does not expose a model list, enter the model ID manually.',
                validator: (value) {
                  if (field.isRequired &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Enter a default model id.';
                  }
                  return null;
                },
              ),
            if (_availableModels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Text(
                  'Loaded ${_availableModels.length} model${_availableModels.length == 1 ? '' : 's'}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5F4634),
                      ),
                ),
              ),
          ],
        );
      case ProviderSchemaFieldIds.headers:
        return _HeadersEditor(
          rows: _headerRows,
          helpText: field.helpText,
          onAddRow: () {
            setState(() {
              _headerRows.add(_HeaderRowController());
            });
          },
          onRemoveRow: (row) {
            setState(() {
              row.dispose();
              _headerRows.remove(row);
            });
          },
          validationMessage: _validateHeaders(),
        );
      case ProviderSchemaFieldIds.temperature:
        return _buildNumericField(
          controller: _temperatureController,
          field: field,
        );
      case ProviderSchemaFieldIds.maxTokens:
        return _buildNumericField(
          controller: _maxTokensController,
          field: field,
          isInteger: true,
        );
      case ProviderSchemaFieldIds.topP:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildNumericField(
              controller: _topPController,
              field: field,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetGenerationDefaults,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset generation defaults'),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? helpText,
    TextInputType? keyboardType,
    String? Function(String? value)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
          validator: validator,
        ),
        if (helpText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              helpText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5F4634),
                  ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNumericField({
    required TextEditingController controller,
    required ProviderFieldSchema field,
    bool isInteger = false,
  }) {
    return _buildTextField(
      controller: controller,
      label: field.label,
      helpText: field.helpText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return null;
        }
        final parsed =
            isInteger ? int.tryParse(trimmed) : double.tryParse(trimmed);
        if (parsed == null) {
          return isInteger
              ? 'Enter a whole number.'
              : 'Enter a numeric value.';
        }
        final numericValue = parsed.toDouble();
        if (field.minNumericValue != null &&
            numericValue < field.minNumericValue!) {
          return 'Must be at least ${field.minNumericValue}.';
        }
        if (field.maxNumericValue != null &&
            numericValue > field.maxNumericValue!) {
          return 'Must be at most ${field.maxNumericValue}.';
        }
        return null;
      },
    );
  }

  void _hydrateFromProvider(Provider? provider) {
    if (provider == null) {
      _headerRows.add(_HeaderRowController());
      _applyKindDefaults();
      _resetGenerationDefaults();
      return;
    }

    _displayNameController.text = provider.displayName;
    _baseUrlController.text = provider.baseUrl;
    _selectedModelId = provider.defaultModelId;
    _manualModelController.text = provider.defaultModelId ?? '';
    _temperatureController.text =
        _readNumericSetting(provider.settings, 'temperature');
    _maxTokensController.text =
        _readNumericSetting(provider.settings, 'max_tokens');
    _topPController.text = _readNumericSetting(provider.settings, 'top_p');

    if (provider.headers.isEmpty) {
      _headerRows.add(_HeaderRowController());
    } else {
      for (final entry in provider.headers.entries) {
        _headerRows.add(
          _HeaderRowController(
            keyText: entry.key,
            valueText: entry.value,
          ),
        );
      }
    }
  }

  void _applyKindDefaults() {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty ||
        displayName == 'Local Ollama' ||
        displayName == 'API Provider' ||
        displayName == 'OpenAI') {
      _displayNameController.text = _selectedKind == ProviderKind.ollama
          ? 'Local Ollama'
          : 'API Provider';
    }

    final currentBaseUrl = _baseUrlController.text.trim();
    if (_selectedKind == ProviderKind.ollama) {
      if (currentBaseUrl.isEmpty ||
          currentBaseUrl == 'https://api.openai.com/v1') {
        _baseUrlController.text =
            widget.lastKnownOllamaEndpoint?.trim().isNotEmpty == true
                ? widget.lastKnownOllamaEndpoint!.trim()
                : 'http://127.0.0.1:11434';
      }
    } else {
      if (currentBaseUrl.isEmpty ||
          currentBaseUrl == 'http://127.0.0.1:11434' ||
          currentBaseUrl == 'http://localhost:11434') {
        _baseUrlController.text = 'https://api.openai.com/v1';
      }
    }
  }

  void _resetGenerationDefaults() {
    // Spec FR-PRV-6: allow reset to provider defaults for generation params.
    _temperatureController.text = '0.7';
    _maxTokensController.clear();
    _topPController.text = '1.0';
  }

  Future<void> _validateConnection() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isValidating = true;
      _statusMessage = null;
    });

    try {
      final apiKey = await _resolveApiKeyForDraft();
      final result =
          await ref.read(providerManagementProvider.notifier).validateDraft(
                _draftProvider(),
                apiKey: apiKey,
              );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusIsSuccess = result.isValid;
        _statusMessage =
            result.isValid ? 'Connection succeeded.' : result.errorMessage;
        _lastValidationFingerprint =
            result.isValid ? _validationFingerprint(apiKey) : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsSuccess = false;
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
      final models = await _fetchModelsForDraft();
      if (!mounted) {
        return;
      }

      final currentSelection = _resolvedModelId;
      final selectedModelId = models.any(
        (model) => model.remoteModelId == currentSelection,
      )
          ? currentSelection
          : (models.isNotEmpty ? models.first.remoteModelId : currentSelection);

      setState(() {
        _availableModels = models;
        _selectedModelId = selectedModelId;
        _statusIsSuccess = models.isNotEmpty;
        _statusMessage = models.isEmpty
            ? 'The provider responded, but it did not return any models.'
            : 'Loaded ${models.length} model${models.length == 1 ? '' : 's'}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsSuccess = false;
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

  Future<List<ProviderModel>> _fetchModelsForDraft() async {
    final apiKey = await _resolveApiKeyForDraft();
    return ref.read(providerManagementProvider.notifier).fetchModelsForDraft(
          _draftProvider(),
          apiKey: apiKey,
        );
  }

  Future<void> _saveProvider() async {
    if (!_validateForm()) {
      return;
    }

    final modelId = await _ensureModelSelection();
    if (modelId == null || modelId.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final draft = _draftProvider().copyWith(defaultModelId: modelId);
      final apiKeyForValidation = await _resolveApiKeyForDraft();
      final requiresConnectivityValidation =
          !(_selectedKind == ProviderKind.openaiCompatible &&
              _clearStoredApiKey &&
              _apiKeyController.text.trim().isEmpty);

      if (requiresConnectivityValidation &&
          _lastValidationFingerprint != _validationFingerprint(apiKeyForValidation)) {
        final result =
            await ref.read(providerManagementProvider.notifier).validateDraft(
                  draft,
                  apiKey: apiKeyForValidation,
                );
        if (!result.isValid) {
          throw Exception(result.errorMessage ?? 'Validation failed.');
        }
      }

      final notifier = ref.read(providerManagementProvider.notifier);
      Provider savedProvider;
      if (_isEditing) {
        final existingProvider = widget.provider!;
        final shouldClearApiKey =
            _selectedKind != ProviderKind.openaiCompatible ||
                (_clearStoredApiKey && _apiKeyController.text.trim().isEmpty);
        savedProvider = await notifier.updateProviderSecret(
          draft.copyWith(
            id: existingProvider.id,
            createdAt: existingProvider.createdAt,
          ),
          apiKey: _apiKeyController.text.trim().isEmpty
              ? null
              : _apiKeyController.text.trim(),
          clearApiKey: shouldClearApiKey,
        );
      } else {
        savedProvider = await notifier.addProvider(
          draft,
          apiKey: _apiKeyController.text.trim(),
        );
      }

      await notifier.refreshProviderHealth(savedProvider.id, force: true);
      ref.invalidate(onboardingProvider);
      ref.invalidate(chatStateProvider);
      ref.invalidate(conversationListProvider);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(savedProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusIsSuccess = false;
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

  Future<String?> _ensureModelSelection() async {
    final directSelection = _resolvedModelId;
    if (_availableModels.isNotEmpty) {
      if (directSelection != null &&
          _availableModels.any(
            (model) => model.remoteModelId == directSelection,
          )) {
        return directSelection;
      }

      try {
        final refreshedModels = await _fetchModelsForDraft();
        if (refreshedModels.isNotEmpty) {
          final nextSelection = refreshedModels.any(
            (model) => model.remoteModelId == directSelection,
          )
              ? directSelection
              : refreshedModels.first.remoteModelId;
          if (mounted) {
            setState(() {
              _availableModels = refreshedModels;
              _selectedModelId = nextSelection;
            });
          }
          return nextSelection;
        }
      } catch (_) {
        // Fall back to the previous manual selection logic below.
      }
    }

    if (directSelection == null || directSelection.isEmpty) {
      if (mounted) {
        setState(() {
          _statusIsSuccess = false;
          _statusMessage = 'Choose a default model before saving.';
        });
      }
      return null;
    }
    return directSelection;
  }

  Future<String?> _resolveApiKeyForDraft() async {
    if (_selectedKind != ProviderKind.openaiCompatible) {
      return null;
    }

    final replacement = _apiKeyController.text.trim();
    if (replacement.isNotEmpty) {
      return replacement;
    }

    if (_clearStoredApiKey) {
      return null;
    }

    final existingProvider = widget.provider;
    if (existingProvider == null) {
      return null;
    }

    final repo = await ref.read(providerRepositoryProvider.future);
    return await repo.getApiKey(existingProvider.id);
  }

  bool _validateForm() {
    final formValid = _formKey.currentState?.validate() ?? false;
    final headerError = _validateHeaders();
    if (formValid && headerError == null) {
      return true;
    }

    setState(() {
      _statusIsSuccess = false;
      _statusMessage = headerError ?? _statusMessage;
    });
    return false;
  }

  String? _validateHeaders() {
    final seenKeys = <String>{};
    for (final row in _headerRows) {
      final key = row.keyController.text.trim();
      final value = row.valueController.text.trim();
      if (key.isEmpty && value.isEmpty) {
        continue;
      }
      if (key.isEmpty || value.isEmpty) {
        return 'Each custom header needs both a key and a value.';
      }
      final normalizedKey = key.toLowerCase();
      if (!seenKeys.add(normalizedKey)) {
        return 'Header keys must be unique.';
      }
    }
    return null;
  }

  Provider _draftProvider() {
    final now = DateTime.now();
    final existingProvider = widget.provider;

    return Provider(
      id: existingProvider?.id ?? 'draft-provider',
      kind: _selectedKind,
      displayName: _displayNameController.text.trim(),
      baseUrl: _normalizeEndpoint(_baseUrlController.text),
      apiKeyRef: existingProvider?.apiKeyRef,
      defaultModelId: _resolvedModelId,
      headers: _buildHeaders(),
      settings: _buildSettings(),
      healthStatus:
          existingProvider?.healthStatus ?? ProviderHealthStatus.neverChecked,
      healthCheckedAt: existingProvider?.healthCheckedAt,
      createdAt: existingProvider?.createdAt ?? now,
      updatedAt: now,
      deletedAt: existingProvider?.deletedAt,
    );
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{};
    for (final row in _headerRows) {
      final key = row.keyController.text.trim();
      final value = row.valueController.text.trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      headers[key] = value;
    }
    return headers;
  }

  Map<String, dynamic> _buildSettings() {
    final settings = <String, dynamic>{};
    final temperature = double.tryParse(_temperatureController.text.trim());
    final maxTokens = int.tryParse(_maxTokensController.text.trim());
    final topP = double.tryParse(_topPController.text.trim());

    if (temperature != null) {
      settings['temperature'] = temperature;
    }
    if (maxTokens != null) {
      settings['max_tokens'] = maxTokens;
    }
    if (topP != null) {
      settings['top_p'] = topP;
    }
    return settings;
  }

  String? get _resolvedModelId {
    if (_selectedModelId != null && _selectedModelId!.trim().isNotEmpty) {
      return _selectedModelId!.trim();
    }
    final manualModelId = _manualModelController.text.trim();
    return manualModelId.isEmpty ? null : manualModelId;
  }

  String _validationFingerprint(String? apiKey) {
    return <Object?>[
      _selectedKind.name,
      _displayNameController.text.trim(),
      _normalizeEndpoint(_baseUrlController.text),
      _resolvedModelId,
      apiKey?.hashCode,
      _buildHeaders().entries
          .map((entry) => '${entry.key}:${entry.value}')
          .join('|'),
      _temperatureController.text.trim(),
      _maxTokensController.text.trim(),
      _topPController.text.trim(),
    ].join('::');
  }

  String _normalizeEndpoint(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'http://$trimmed';
  }

  String _readNumericSetting(Map<String, dynamic> settings, String key) {
    final value = settings[key];
    return value == null ? '' : '$value';
  }
}

class _ProviderStatusBanner extends StatelessWidget {
  final ProviderHealthStatus? status;
  final DateTime? checkedAt;
  final String? message;
  final bool isSuccess;

  const _ProviderStatusBanner({
    required this.status,
    required this.checkedAt,
    required this.message,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedMessage = message ?? _healthDescription(status);
    final backgroundColor = message != null
        ? (isSuccess ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6))
        : _healthBackground(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            message != null
                ? (isSuccess
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded)
                : _healthIcon(status),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message != null ? 'Connection status' : _healthLabel(status),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  resolvedMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (checkedAt != null && message == null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Last checked ${TimeOfDay.fromDateTime(checkedAt!).format(context)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5F4634),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OllamaHintsPanel extends ConsumerWidget {
  final String selectedEndpoint;
  final String? lastKnownEndpoint;
  final void Function(String endpoint, String label) onUseEndpoint;

  const _OllamaHintsPanel({
    required this.selectedEndpoint,
    required this.lastKnownEndpoint,
    required this.onUseEndpoint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final discoveryState = ref.watch(ollamaDiscoveryProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: discoveryState.isScanning
                      ? null
                      : () {
                          ref
                              .read(ollamaDiscoveryProvider.notifier)
                              .scan(lastKnownEndpoint: lastKnownEndpoint);
                        },
                  icon: discoveryState.isScanning
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
              'Spec FR-ONB-3: probe localhost quickly, optionally scan the LAN, and keep manual entry available even if discovery fails.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5F4634),
                height: 1.45,
              ),
            ),
            if (lastKnownEndpoint != null &&
                lastKnownEndpoint!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 18),
                label: Text(lastKnownEndpoint!),
                onPressed: () => onUseEndpoint(
                  lastKnownEndpoint!,
                  'Last successful endpoint',
                ),
              ),
            ],
            if (discoveryState.error != null) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                discoveryState.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9C2F2F),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (discoveryState.candidates.isEmpty && !discoveryState.isScanning)
              Text(
                'No candidates discovered yet. Manual entry is still available above.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5F4634),
                ),
              ),
            ...discoveryState.candidates.map(
              (candidate) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: candidate.endpoint == selectedEndpoint
                          ? const Color(0xFFB85C38)
                          : Colors.transparent,
                    ),
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
                    onPressed: () =>
                        onUseEndpoint(candidate.endpoint, candidate.label),
                    child: const Text('Use'),
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

class _OpenAiCompatibleHintsPanel extends StatelessWidget {
  const _OpenAiCompatibleHintsPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.cloud_queue_rounded,
                    color: Color(0xFF264653)),
                const SizedBox(width: 10),
                Text(
                  'OpenAI-compatible setup',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF17313A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Use this for OpenAI, OpenRouter, Groq, or self-hosted gateways that expose `/models` and `/chat/completions`.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF36525A),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadersEditor extends StatelessWidget {
  final List<_HeaderRowController> rows;
  final String? helpText;
  final VoidCallback onAddRow;
  final ValueChanged<_HeaderRowController> onRemoveRow;
  final String? validationMessage;

  const _HeadersEditor({
    required this.rows,
    required this.helpText,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.validationMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Custom headers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAddRow,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add header'),
            ),
          ],
        ),
        if (helpText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              helpText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5F4634),
                  ),
            ),
          ),
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: row.keyController,
                    decoration: const InputDecoration(
                      labelText: 'Header key',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.valueController,
                    decoration: const InputDecoration(
                      labelText: 'Header value',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: rows.length == 1 ? null : () => onRemoveRow(row),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
        if (validationMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              validationMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9C2F2F),
                  ),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _HeaderRowController {
  final TextEditingController keyController;
  final TextEditingController valueController;

  _HeaderRowController({
    String keyText = '',
    String valueText = '',
  })  : keyController = TextEditingController(text: keyText),
        valueController = TextEditingController(text: valueText);

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
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
      return 'The provider responded successfully and is ready for requests.';
    case ProviderHealthStatus.degraded:
      return 'The provider responded, but authentication or endpoint details need attention.';
    case ProviderHealthStatus.unreachable:
      return 'The provider could not be reached within the health-check timeout.';
    case ProviderHealthStatus.neverChecked:
    case null:
      return 'No health probe has been run yet.';
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

Color _healthBackground(ProviderHealthStatus? status) {
  switch (status) {
    case ProviderHealthStatus.healthy:
      return const Color(0xFFE6F4EA);
    case ProviderHealthStatus.degraded:
      return const Color(0xFFF9EDD0);
    case ProviderHealthStatus.unreachable:
      return const Color(0xFFFCE8E6);
    case ProviderHealthStatus.neverChecked:
    case null:
      return const Color(0xFFF3EEE8);
  }
}
