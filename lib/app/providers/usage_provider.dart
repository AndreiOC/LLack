import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/usage_service.dart';
import 'repository_providers.dart';

final usageServiceProvider = FutureProvider<UsageService>((ref) async {
  final usageDao = await ref.watch(usageSnapshotDaoProvider.future);
  final appSettingDao = await ref.watch(appSettingDaoProvider.future);
  final providerRepository = await ref.watch(providerRepositoryProvider.future);
  return UsageService(
    usageDao: usageDao,
    appSettingDao: appSettingDao,
    providerRepository: providerRepository,
  );
});

final usageOverviewProvider = FutureProvider<UsageOverview>((ref) async {
  final usageService = await ref.watch(usageServiceProvider.future);
  return usageService.getOverview();
});
