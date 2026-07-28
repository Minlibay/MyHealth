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

class MyHealthApp extends ConsumerStatefulWidget {
  const MyHealthApp({super.key});

  @override
  ConsumerState<MyHealthApp> createState() => _MyHealthAppState();
}

class _MyHealthAppState extends ConsumerState<MyHealthApp>
    with WidgetsBindingObserver {
  DateTime? _lastResumeSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// При возврате в приложение подтягиваем свежие данные (не чаще раза в
  /// 15 минут) — иначе дашборд ждал перезапуска приложения.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (_lastResumeSync != null &&
        now.difference(_lastResumeSync!) < const Duration(minutes: 15)) {
      return;
    }
    _lastResumeSync = now;
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Авто-синхронизация только при смене пользователя (вход/старт с
    // сохранённой сессией), а НЕ на каждое обновление токена — иначе
    // синхронизация запускалась бы постоянно при ротации access-токена.
    ref.listen(authControllerProvider, (prev, next) {
      final prevId = prev?.value?.userId;
      final nextId = next.value?.userId;
      if (nextId != null && nextId != prevId) {
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
