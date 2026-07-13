import 'package:home_widget/home_widget.dart';

/// Обновляет данные домашнего виджета (Android AppWidget; на iOS —
/// WidgetKit-расширение, см. ios/HomeWidgetExtension/README.md).
Future<void> updateHomeWidget({
  int? health,
  int? sleep,
  int? recovery,
}) async {
  try {
    // iOS: данные виджета живут в общей app group (см. ios/HomeWidgetExtension).
    await HomeWidget.setAppGroupId('group.com.myhealthv.app');
    await HomeWidget.saveWidgetData<String>('health', health?.toString() ?? '—');
    await HomeWidget.saveWidgetData<String>('sleep', sleep?.toString() ?? '—');
    await HomeWidget.saveWidgetData<String>(
        'recovery', recovery?.toString() ?? '—');
    await HomeWidget.updateWidget(
      androidName: 'ScoreWidgetProvider',
      iOSName: 'ScoreWidget',
    );
  } catch (_) {
    // Виджет не добавлен/платформа не поддерживает — не мешаем приложению.
  }
}
