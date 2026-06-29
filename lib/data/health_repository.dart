import '../core/health_metric.dart';
import 'metric_reading.dart';
import 'metric_sample.dart';

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
}
