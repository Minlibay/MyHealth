import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _plugin = FlutterLocalNotificationsPlugin();
var _initialized = false;

/// Инициализация плагина уведомлений (безопасно вызывать многократно,
/// в том числе из фонового isolate).
Future<void> initNotifications() async {
  if (_initialized) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios));
  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  _initialized = true;
}

const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'anomalies',
    'Отклонения от нормы',
    channelDescription:
        'Показатели здоровья вышли за пределы вашей личной нормы',
    importance: Importance.defaultImportance,
  ),
  iOS: DarwinNotificationDetails(),
);

/// Показывает уведомления об аномалиях. Каждая аномалия показывается
/// не чаще раза в сутки (дедупликация по дню и ключу метрики).
Future<void> notifyAnomalies(
    List<({String key, String message})> anomalies) async {
  if (anomalies.isEmpty) return;
  await initNotifications();

  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now();
  final day = '${today.year}-${today.month}-${today.day}';
  final shown = (prefs.getStringList('notified_anomalies_v1') ?? [])
      .where((e) => e.startsWith('$day:'))
      .toSet();

  var id = day.hashCode & 0x7fff;
  final nextShown = {...shown};
  for (final a in anomalies) {
    final dedupeKey = '$day:${a.key}';
    if (shown.contains(dedupeKey)) continue;
    nextShown.add(dedupeKey);
    await _plugin.show(
      id: id++,
      title: 'MyHealth: отклонение от нормы',
      body: a.message,
      notificationDetails: _details,
    );
  }
  await prefs.setStringList('notified_anomalies_v1', nextShown.toList());
}
