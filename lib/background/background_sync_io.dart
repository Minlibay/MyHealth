import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/health_metric.dart';
import '../data/api/api_client.dart';
import '../data/api/metrics_api.dart';
import '../data/api/workouts_api.dart';
import '../data/auth/auth_session.dart';
import '../data/health_repository_factory.dart';
import '../data/sync_settings.dart' show syncHealthStoreKey;
import '../notifications/notifications_io.dart';

const _syncTask = 'com.myhealth.bgSync';

/// Точка входа фоновой задачи. Выполняется в отдельном isolate —
/// без Riverpod: собственные экземпляры хранилища, клиента и репозитория.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Настройки синхронизации: хранилище платформы можно выключить.
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(syncHealthStoreKey) ?? true)) return true;

      const storage = FlutterSecureStorage();
      final raw = await storage.read(key: 'auth_session_v1');
      if (raw == null) return true; // не вошли — синхронизировать нечего

      var session = AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final client = ApiClient()
        ..token = session.token
        ..refreshToken = session.refreshToken
        ..onTokensRefreshed = (t, r) {
          session = session.copyWith(token: t, refreshToken: r);
          storage.write(key: 'auth_session_v1', value: jsonEncode(session.toJson()));
        };

      final device = createHealthRepository();
      final metricsApi = MetricsApi(client);
      // Короткое окно: фоновая задача ходит часто, глубину добирает
      // ручная синхронизация из приложения. Запросить разрешения из фона
      // нельзя — недоступные метрики просто пропускаем.
      for (final metric in HealthMetric.values) {
        try {
          final series = await device.fetchSeries(metric, days: 7);
          await metricsApi.uploadSamples(metric, series);
        } catch (_) {
          continue;
        }
      }
      try {
        final workouts = await device.fetchWorkouts(days: 7);
        await WorkoutsApi(client).uploadWorkouts(workouts);
      } catch (_) {}

      // После выгрузки проверяем аномалии и показываем уведомления —
      // так «пульс выше вашей нормы» приходит, даже когда приложение закрыто.
      try {
        final res = await client.dio.get('/api/insights');
        if (res.statusCode == 200 && res.data is Map) {
          final anomalies = ((res.data as Map)['anomalies'] as List? ?? []);
          await notifyAnomalies([
            for (final a in anomalies)
              (
                key: (a as Map)['metric'].toString(),
                message: a['message'] as String,
              ),
          ]);
        }
      } catch (_) {}
      return true;
    } catch (_) {
      // false → WorkManager повторит задачу по своей политике.
      return false;
    }
  });
}

/// Регистрирует периодическую фоновую синхронизацию (раз в ~4 часа,
/// только при наличии сети). Повторные вызовы безопасны.
Future<void> initBackgroundSync() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _syncTask,
    _syncTask,
    // Чаще — чтобы данные обновлялись без ручного запуска. Система сама
    // решает, когда именно выполнить задачу (Android ≥15 мин, iOS реже).
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
