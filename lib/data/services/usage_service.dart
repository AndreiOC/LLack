import '../../data/db/dao/app_setting_dao.dart';
import '../../data/db/dao/usage_snapshot_dao.dart';
import '../../data/repositories/provider_repository.dart';
import '../../domain/entities/entities.dart';

enum UsageThresholdState {
  none,
  approaching,
  exceeded,
}

class UsageMetric {
  final int inputTokens;
  final int outputTokens;
  final int estimatedCostMicros;

  const UsageMetric({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.estimatedCostMicros = 0,
  });

  int get totalTokens => inputTokens + outputTokens;
  double get estimatedCostDollars => estimatedCostMicros / 1000000;

  UsageMetric copyWith({
    int? inputTokens,
    int? outputTokens,
    int? estimatedCostMicros,
  }) {
    return UsageMetric(
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      estimatedCostMicros: estimatedCostMicros ?? this.estimatedCostMicros,
    );
  }
}

class ProviderUsageMetric {
  final String providerId;
  final String providerName;
  final bool isLocal;
  final UsageMetric totals;

  const ProviderUsageMetric({
    required this.providerId,
    required this.providerName,
    required this.isLocal,
    required this.totals,
  });
}

class UsageOverview {
  final UsageMetric daily;
  final UsageMetric weekly;
  final UsageMetric monthly;
  final UsageMetric monthlyLocal;
  final UsageMetric monthlyCloud;
  final List<ProviderUsageMetric> providerBreakdown;
  final int? monthlyThresholdMicros;
  final UsageThresholdState thresholdState;
  final bool shouldShowThresholdBanner;

  const UsageOverview({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.monthlyLocal,
    required this.monthlyCloud,
    required this.providerBreakdown,
    required this.monthlyThresholdMicros,
    required this.thresholdState,
    required this.shouldShowThresholdBanner,
  });

  double? get monthlyThresholdDollars =>
      monthlyThresholdMicros == null ? null : monthlyThresholdMicros! / 1000000;
}

class UsageService {
  static const double _approachingThresholdFactor = 0.8;
  static const String _thresholdAlertPrefix = 'monthly_spend_alert_seen';

  final UsageSnapshotDao _usageDao;
  final AppSettingDao _appSettingDao;
  final ProviderRepository _providerRepository;

  UsageService({
    required UsageSnapshotDao usageDao,
    required AppSettingDao appSettingDao,
    required ProviderRepository providerRepository,
  })  : _usageDao = usageDao,
        _appSettingDao = appSettingDao,
        _providerRepository = providerRepository;

  Future<void> recordMessageUsage({
    required String conversationId,
    required String messageId,
    required Provider provider,
    required String? modelId,
    required int inputTokens,
    required int outputTokens,
    required int estimatedCostMicros,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final periods = <(String, DateTime, DateTime)>[
      ('daily', _startOfDay(now), _endOfDay(now)),
      ('weekly', _startOfWeek(now), _endOfWeek(now)),
      ('monthly', _startOfMonth(now), _endOfMonth(now)),
    ];

    for (final (periodType, periodStart, periodEnd) in periods) {
      await _usageDao.upsert(
        UsageSnapshot(
          id: '$messageId:$periodType',
          conversationId: conversationId,
          messageId: messageId,
          providerId: provider.id,
          modelId: modelId,
          periodStart: periodStart,
          periodEnd: periodEnd,
          periodType: periodType,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          estimatedCostMicros: estimatedCostMicros,
          isLocal: provider.isOllama,
          createdAt: now,
        ),
      );
    }
  }

  Future<UsageOverview> getOverview({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final dailyStart = _startOfDay(clock);
    final weeklyStart = _startOfWeek(clock);
    final monthlyStart = _startOfMonth(clock);

    final dailySnapshots = await _usageDao.getByPeriod(
      periodType: 'daily',
      periodStart: dailyStart,
    );
    final weeklySnapshots = await _usageDao.getByPeriod(
      periodType: 'weekly',
      periodStart: weeklyStart,
    );
    final monthlySnapshots = await _usageDao.getByPeriod(
      periodType: 'monthly',
      periodStart: monthlyStart,
    );

    final providers = await _providerRepository.getAll(includeDeleted: true);
    final providerNames = <String, String>{
      for (final provider in providers) provider.id: provider.displayName,
    };

    final monthlyThresholdMicros =
        await _appSettingDao.getInt(AppSettingKeys.monthlySpendThreshold);
    final monthly = _sum(monthlySnapshots);
    final monthlyLocal = _sum(
      monthlySnapshots.where((snapshot) => snapshot.isLocal),
    );
    final monthlyCloud = _sum(
      monthlySnapshots.where((snapshot) => !snapshot.isLocal),
    );
    final thresholdState = _thresholdState(
      spendMicros: monthlyCloud.estimatedCostMicros,
      thresholdMicros: monthlyThresholdMicros,
    );

    return UsageOverview(
      daily: _sum(dailySnapshots),
      weekly: _sum(weeklySnapshots),
      monthly: monthly,
      monthlyLocal: monthlyLocal,
      monthlyCloud: monthlyCloud,
      providerBreakdown:
          _buildProviderBreakdown(monthlySnapshots, providerNames),
      monthlyThresholdMicros: monthlyThresholdMicros,
      thresholdState: thresholdState,
      shouldShowThresholdBanner: await _shouldShowThresholdBanner(
        clock,
        thresholdState,
      ),
    );
  }

  Future<void> setMonthlySpendThresholdDollars(double? value) async {
    final micros = value == null ? null : (value * 1000000).round();
    await _appSettingDao.setInt(AppSettingKeys.monthlySpendThreshold, micros);
  }

  Future<void> acknowledgeThresholdBanner({
    required UsageThresholdState state,
    DateTime? now,
  }) async {
    if (state == UsageThresholdState.none) {
      return;
    }

    await _appSettingDao.setString(
      _thresholdAlertKey(now ?? DateTime.now()),
      state.name,
    );
  }

  List<ProviderUsageMetric> _buildProviderBreakdown(
    List<UsageSnapshot> snapshots,
    Map<String, String> providerNames,
  ) {
    final aggregates = <String, ProviderUsageMetric>{};
    for (final snapshot in snapshots) {
      final providerId = snapshot.providerId ?? 'unknown';
      final existing = aggregates[providerId];
      final nextTotals = _merge(
        existing?.totals ?? const UsageMetric(),
        UsageMetric(
          inputTokens: snapshot.inputTokens,
          outputTokens: snapshot.outputTokens,
          estimatedCostMicros: snapshot.estimatedCostMicros,
        ),
      );
      aggregates[providerId] = ProviderUsageMetric(
        providerId: providerId,
        providerName: providerNames[providerId] ?? 'Unknown provider',
        isLocal: snapshot.isLocal,
        totals: nextTotals,
      );
    }

    final breakdown = aggregates.values.toList();
    breakdown.sort(
      (left, right) => right.totals.estimatedCostMicros.compareTo(
                left.totals.estimatedCostMicros,
              ) !=
              0
          ? right.totals.estimatedCostMicros.compareTo(
              left.totals.estimatedCostMicros,
            )
          : right.totals.totalTokens.compareTo(left.totals.totalTokens),
    );
    return breakdown;
  }

  UsageMetric _sum(Iterable<UsageSnapshot> snapshots) {
    var inputTokens = 0;
    var outputTokens = 0;
    var estimatedCostMicros = 0;
    for (final snapshot in snapshots) {
      inputTokens += snapshot.inputTokens;
      outputTokens += snapshot.outputTokens;
      estimatedCostMicros += snapshot.estimatedCostMicros;
    }
    return UsageMetric(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      estimatedCostMicros: estimatedCostMicros,
    );
  }

  UsageMetric _merge(UsageMetric left, UsageMetric right) {
    return UsageMetric(
      inputTokens: left.inputTokens + right.inputTokens,
      outputTokens: left.outputTokens + right.outputTokens,
      estimatedCostMicros: left.estimatedCostMicros + right.estimatedCostMicros,
    );
  }

  UsageThresholdState _thresholdState({
    required int spendMicros,
    required int? thresholdMicros,
  }) {
    if (thresholdMicros == null || thresholdMicros <= 0) {
      return UsageThresholdState.none;
    }
    if (spendMicros >= thresholdMicros) {
      return UsageThresholdState.exceeded;
    }
    if (spendMicros >=
        (thresholdMicros * _approachingThresholdFactor).round()) {
      return UsageThresholdState.approaching;
    }
    return UsageThresholdState.none;
  }

  Future<bool> _shouldShowThresholdBanner(
    DateTime now,
    UsageThresholdState currentState,
  ) async {
    if (currentState == UsageThresholdState.none) {
      return false;
    }

    final storedValue = await _appSettingDao.getString(_thresholdAlertKey(now));
    final storedState = UsageThresholdState.values.firstWhere(
      (value) => value.name == storedValue,
      orElse: () => UsageThresholdState.none,
    );
    return currentState.index > storedState.index;
  }

  String _thresholdAlertKey(DateTime now) {
    final month = now.month.toString().padLeft(2, '0');
    return '$_thresholdAlertPrefix-${now.year}-$month';
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _endOfDay(DateTime value) {
    return _startOfDay(value).add(const Duration(days: 1));
  }

  DateTime _startOfWeek(DateTime value) {
    final dayStart = _startOfDay(value);
    final difference = dayStart.weekday - DateTime.monday;
    return dayStart.subtract(Duration(days: difference));
  }

  DateTime _endOfWeek(DateTime value) {
    return _startOfWeek(value).add(const Duration(days: 7));
  }

  DateTime _startOfMonth(DateTime value) {
    return DateTime(value.year, value.month);
  }

  DateTime _endOfMonth(DateTime value) {
    return DateTime(value.year, value.month + 1);
  }
}
