import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'background/background_sync.dart';
import 'core/theme.dart';
import 'data/auth/auth_controller.dart';
import 'data/ring/ring_connection.dart';
import 'data/ring/ring_sync.dart';
import 'notifications/notifications.dart';
import 'providers.dart';
import 'router.dart';
import 'widget/widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Данные локали для форматирования дат (DateFormat с 'ru').
  await initializeDateFormatting('ru');
  // Периодическая выгрузка данных на сервер, когда приложение закрыто.
  await initBackgroundSync();
  runApp(const ProviderScope(child: MyHealthApp()));
}

class MyHealthApp extends ConsumerWidget {
  const MyHealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Авто-синхронизация: при входе (и старте с сохранённой сессией)
    // выгружаем данные устройства на сервер.
    ref.listen(authControllerProvider, (prev, next) {
      if (next.value != null) {
        ref.read(syncControllerProvider.notifier).syncNow();
      }
    });
    // Автоподключение к активному сохранённому устройству при старте.
    ref.watch(ringDevicesProvider);
    // Контроллер живёт с запуска: ловит подключение кольца и сразу
    // включает автозамеры + выкачивает накопленную историю.
    ref.watch(ringSyncProvider);
    // Уведомления об отклонениях от личной нормы (раз в сутки на аномалию)
    // и обновление домашнего виджета со скорами.
    ref.listen(insightsProvider, (_, next) {
      final data = next.value;
      if (data == null) return;
      updateHomeWidget(
        health: data.healthScore,
        sleep: data.sleepScore,
        recovery: data.readinessScore,
      );
      if (data.anomalies.isEmpty) return;
      notifyAnomalies([
        for (final a in data.anomalies)
          (key: a.metric.name, message: a.message),
      ]);
    });

    return MaterialApp.router(
      title: 'MyHealth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
