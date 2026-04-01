part of 'main.dart';

class AppNotificationScheduler {
  AppNotificationScheduler._();

  static final AppNotificationScheduler instance = AppNotificationScheduler._();

  static const String _channelId = 'expiry-reminders';
  static const String _channelName = 'Expiry reminders';
  static const String _channelDescription =
      'Alerts scheduled before food items expire.';
  static const String _activeIdsKey =
      'family_eating.inventory_notification_ids';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) {
      return;
    }
    _isInitialized = true;

    tzdata.initializeTimeZones();
    try {
      final TimezoneInfo timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      // Keep the package default if the device timezone cannot be resolved.
    }

    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinInitializationSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
          defaultPresentBanner: true,
          defaultPresentList: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidInitializationSettings,
          iOS: darwinInitializationSettings,
          macOS: darwinInitializationSettings,
        );

    await _plugin.initialize(settings: initializationSettings);

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<bool> requestPermissionsIfNeeded() async {
    if (kIsWeb) {
      return true;
    }
    await initialize();

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final AndroidFlutterLocalNotificationsPlugin? implementation =
            _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final bool enabled =
            await implementation?.areNotificationsEnabled() ?? false;
        if (enabled) {
          return true;
        }
        return await implementation?.requestNotificationsPermission() ?? false;
      case TargetPlatform.iOS:
        final IOSFlutterLocalNotificationsPlugin? implementation =
            _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await implementation?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
      case TargetPlatform.macOS:
        final MacOSFlutterLocalNotificationsPlugin? implementation =
            _plugin.resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        return await implementation?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
      default:
        return true;
    }
  }

  Future<void> syncInventoryNotifications(List<InventoryItem> items) async {
    if (kIsWeb) {
      return;
    }
    await initialize();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<int> previousIds = (prefs.getStringList(_activeIdsKey) ??
            const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toList(growable: false);
    for (final int id in previousIds) {
      await _plugin.cancel(id: id);
    }

    final List<int> activeIds = <int>[];
    for (final InventoryItem item in items) {
      for (int index = 0; index < item.reminders.length; index++) {
        final InventoryReminder reminder = item.reminders[index];
        final DateTime scheduledAt = DateTime(
          item.expiryDate.year,
          item.expiryDate.month,
          item.expiryDate.day,
        ).subtract(Duration(days: reminder.daysBeforeExpiry));
        final DateTime scheduledDateTime = DateTime(
          scheduledAt.year,
          scheduledAt.month,
          scheduledAt.day,
          reminder.hour,
          reminder.minute,
        );
        if (!scheduledDateTime.isAfter(DateTime.now())) {
          continue;
        }

        final int id = _notificationIdFor(item.id, index);
        await _plugin.zonedSchedule(
          id: id,
          title: item.name,
          body: _notificationBody(item, reminder),
          scheduledDate: tz.TZDateTime.from(scheduledDateTime, tz.local),
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: item.id,
        );
        activeIds.add(id);
      }
    }

    await prefs.setStringList(
      _activeIdsKey,
      activeIds.map((int id) => '$id').toList(growable: false),
    );
  }

  NotificationDetails get _notificationDetails {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(threadIdentifier: _channelId),
      macOS: DarwinNotificationDetails(threadIdentifier: _channelId),
    );
  }

  String _notificationBody(InventoryItem item, InventoryReminder reminder) {
    final String dayLabel = switch (reminder.daysBeforeExpiry) {
      0 => 'today',
      1 => 'tomorrow',
      _ => 'in ${reminder.daysBeforeExpiry} days',
    };
    return '${item.name} expires $dayLabel.';
  }

  int _notificationIdFor(String itemId, int reminderIndex) {
    int hash = 17;
    for (final int codeUnit in itemId.codeUnits) {
      hash = 0x1fffffff & ((hash * 37) + codeUnit);
    }
    hash = 0x1fffffff & ((hash * 37) + reminderIndex);
    return hash & 0x7fffffff;
  }
}
