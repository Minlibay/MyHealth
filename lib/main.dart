import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'data/auth/auth_controller.dart';
import 'providers.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Данные локали для форматирования дат (DateFormat с 'ru').
  await initializeDateFormatting('ru');
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
