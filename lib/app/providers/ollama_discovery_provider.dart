import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../data/services/adapters/ollama_adapter.dart';
import '../../domain/entities/entities.dart';

final ollamaDiscoveryProvider =
    AutoDisposeNotifierProvider<OllamaDiscoveryNotifier, OllamaDiscoveryState>(
  OllamaDiscoveryNotifier.new,
);

class OllamaDiscoveryState {
  final bool isScanning;
  final List<OllamaEndpointCandidate> candidates;
  final String? error;

  const OllamaDiscoveryState({
    required this.isScanning,
    required this.candidates,
    required this.error,
  });

  const OllamaDiscoveryState.initial()
      : isScanning = false,
        candidates = const <OllamaEndpointCandidate>[],
        error = null;

  OllamaDiscoveryState copyWith({
    bool? isScanning,
    List<OllamaEndpointCandidate>? candidates,
    Object? error = _sentinel,
  }) {
    return OllamaDiscoveryState(
      isScanning: isScanning ?? this.isScanning,
      candidates: candidates ?? this.candidates,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();
}

class OllamaEndpointCandidate {
  final String label;
  final String endpoint;
  final String source;
  final bool isReachable;
  final int? modelCount;
  final String? detail;

  const OllamaEndpointCandidate({
    required this.label,
    required this.endpoint,
    required this.source,
    required this.isReachable,
    required this.modelCount,
    required this.detail,
  });
}

class OllamaDiscoveryNotifier
    extends AutoDisposeNotifier<OllamaDiscoveryState> {
  final OllamaAdapter _adapter = OllamaAdapter();

  @override
  OllamaDiscoveryState build() => const OllamaDiscoveryState.initial();

  Future<void> scan({String? lastKnownEndpoint}) async {
    state = state.copyWith(isScanning: true, error: null);

    try {
      final seeds = <String, _DiscoverySeed>{
        for (final seed in _defaultSeeds()) seed.endpoint: seed,
      };
      if (lastKnownEndpoint != null && lastKnownEndpoint.trim().isNotEmpty) {
        final endpoint = _normalizeEndpoint(lastKnownEndpoint);
        seeds[endpoint] = _DiscoverySeed(
          label: 'Last successful endpoint',
          endpoint: endpoint,
          source: 'Saved',
        );
      }

      final discoveredSeeds = await _discoverBonjourSeeds();
      for (final seed in discoveredSeeds) {
        seeds[seed.endpoint] = seed;
      }

      final results = await Future.wait(
        seeds.values.map(_probeSeed),
      );
      results.sort(_compareCandidates);

      state = state.copyWith(
        isScanning: false,
        candidates: results,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isScanning: false,
        error: 'Ollama discovery failed: $error',
      );
    }
  }

  Future<OllamaEndpointCandidate> _probeSeed(_DiscoverySeed seed) async {
    final now = DateTime.now();
    final provider = Provider(
      id: seed.endpoint,
      kind: ProviderKind.ollama,
      displayName: seed.label,
      baseUrl: seed.endpoint,
      healthStatus: ProviderHealthStatus.neverChecked,
      createdAt: now,
      updatedAt: now,
    );

    final validation = await _adapter.validateConfig(provider);
    if (!validation.isValid) {
      return OllamaEndpointCandidate(
        label: seed.label,
        endpoint: seed.endpoint,
        source: seed.source,
        isReachable: false,
        modelCount: null,
        detail: validation.errorMessage,
      );
    }

    int? modelCount;
    try {
      final models = await _adapter.fetchModels(provider);
      modelCount = models.length;
    } catch (_) {
      modelCount = validation.metadata?['models_available'] as int?;
    }

    final detail = modelCount == null
        ? 'Reachable'
        : '$modelCount model${modelCount == 1 ? '' : 's'} available';

    return OllamaEndpointCandidate(
      label: seed.label,
      endpoint: seed.endpoint,
      source: seed.source,
      isReachable: true,
      modelCount: modelCount,
      detail: detail,
    );
  }

  Future<List<_DiscoverySeed>> _discoverBonjourSeeds() async {
    if (kIsWeb) {
      return const <_DiscoverySeed>[];
    }

    final discovery = BonsoirDiscovery(
      type: '_ollama._tcp',
      printLogs: false,
    );
    final seeds = <String, _DiscoverySeed>{};
    StreamSubscription<BonsoirDiscoveryEvent>? subscription;

    try {
      await discovery.ready;
      subscription = discovery.eventStream?.listen((event) {
        final service = event.service;
        if (service == null) {
          return;
        }

        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          unawaited(service.resolve(discovery.serviceResolver));
        }

        if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved &&
            service is ResolvedBonsoirService &&
            service.host != null) {
          final endpoint = _buildEndpoint(service.host!, service.port);
          seeds[endpoint] = _DiscoverySeed(
            label: service.name,
            endpoint: endpoint,
            source: 'Bonjour',
          );
        }
      });

      await discovery.start();
      await Future<void>.delayed(const Duration(seconds: 4));
      await discovery.stop();
    } catch (_) {
      return const <_DiscoverySeed>[];
    } finally {
      await subscription?.cancel();
    }

    return seeds.values.toList();
  }

  List<_DiscoverySeed> _defaultSeeds() {
    return const <_DiscoverySeed>[
      _DiscoverySeed(
        label: 'Local machine',
        endpoint: 'http://127.0.0.1:11434',
        source: 'Default',
      ),
      _DiscoverySeed(
        label: 'Localhost',
        endpoint: 'http://localhost:11434',
        source: 'Default',
      ),
      _DiscoverySeed(
        label: 'Android emulator host',
        endpoint: 'http://10.0.2.2:11434',
        source: 'Default',
      ),
    ];
  }

  int _compareCandidates(
    OllamaEndpointCandidate left,
    OllamaEndpointCandidate right,
  ) {
    if (left.isReachable != right.isReachable) {
      return left.isReachable ? -1 : 1;
    }
    if (left.source != right.source) {
      return left.source.compareTo(right.source);
    }
    return left.endpoint.compareTo(right.endpoint);
  }

  String _buildEndpoint(String host, int port) {
    final normalizedHost =
        host.contains(':') && !host.startsWith('[') ? '[$host]' : host;
    return 'http://$normalizedHost:$port';
  }

  String _normalizeEndpoint(String endpoint) {
    final trimmed = endpoint.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'http://$trimmed';
  }
}

class _DiscoverySeed {
  final String label;
  final String endpoint;
  final String source;

  const _DiscoverySeed({
    required this.label,
    required this.endpoint,
    required this.source,
  });
}
