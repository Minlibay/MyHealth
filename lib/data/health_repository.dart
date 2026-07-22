import '../core/health_metric.dart';
import 'metric_reading.dart';
import 'metric_sample.dart';
import 'workout.dart';

/// Статус доступности хранилища здоровья на устройстве.
enum HealthAvailability {
  /// Всё готово — можно запрашивать разрешения и читать данные.
  available,

  /// Android: Health Connect не установлен.
  needsInstall,

  /// Android: Health Connect требует обновления.
  needsUpdate,

  /// Платформа не поддерживается (Web/десктоп — используется фейковый источник).
  unsupported,
}

/// Абстракция над источником данных о здоровье.
///
/// Реализации:
///  * [реальная] поверх пакета `health` (HealthKit / Health Connect) — мобильные;
///  * фейковая с моковыми данными — Web и разработка UI.
abstract class HealthRepository {
  /// Доступно ли хранилище здоровья на этой платформе.
  Future<HealthAvailability> checkAvailability();

  /// Открыть установку Health Connect (только Android).
  Future<void> installHealthConnect();

  /// Запросить разрешения на чтение. true — доступ предоставлен.
  Future<bool> requestPermissions();

  /// Проверить, выданы ли разрешения (без запроса). null — статус неизвестен.
  Future<bool?> hasPermissions();

  /// Отозвать выданные разрешения.
  Future<void> revokePermissions();

  /// Последнее значение по каждому показателю за последние [days] дней.
  Future<Map<HealthMetric, MetricReading?>> fetchLatestAll({int days});

  /// История одного показателя за последние [days] дней (по возрастанию времени).
  Future<List<MetricSample>> fetchSeries(HealthMetric metric, {int days});

  /// Тренировки за последние [days] дней (новые первыми).
  Future<List<Workout>> fetchWorkouts({int days});

  /// Диагностика: по каждому показателю — доступность типа, число записей
  /// за [days] дней и приложения-источники (какие приложения реально
  /// пишут данные в хранилище). Пустой список — платформа без хранилища.
  Future<List<MetricDiagnostic>> diagnostics({int days});
}

/// Строка диагностики хранилища по одному показателю.
class MetricDiagnostic {
  const MetricDiagnostic({
    required this.metric,
    required this.available,
    required this.recordCount,
    required this.sources,
  });

  final HealthMetric metric;

  /// Тип данных поддерживается платформой/хранилищем.
  final bool available;

  /// Сколько записей нашлось за период.
  final int recordCount;

  /// Имена приложений/устройств, записавших данные (например «Fitbit»).
  final List<String> sources;
}
