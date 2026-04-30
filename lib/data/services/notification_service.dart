import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for local notifications (spending alerts, background sync status).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize notification channels and permissions.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Show a spending threshold alert notification.
  Future<void> showSpendingAlert({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'spending_alerts',
      'Spending Alerts',
      channelDescription: 'Notifications when monthly cloud spend crosses thresholds',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.active,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: LinuxNotificationDetails(),
    );

    await _plugin.show(
      0,
      title,
      body,
      details,
    );
  }

  /// Show a background sync completion notification.
  Future<void> showSyncComplete({int processedCount = 0}) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'background_sync',
      'Background Sync',
      channelDescription: 'Notifications for outbox background sync results',
      importance: Importance.low,
      priority: Priority.low,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      1,
      'Sync complete',
      processedCount > 0
          ? '$processedCount message(s) sent in background.'
          : 'No pending messages.',
      details,
    );
  }
}
