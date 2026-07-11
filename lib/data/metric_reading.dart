import '../core/health_metric.dart' show HealthMetric;
import '../core/health_status.dart';
import '../core/metric_source.dart';

/// Одно «последнее» значение показателя для отображения на дашборде.
class MetricReading {
  const MetricReading({
    required this.metric,
    required this.displayValue,
    required this.time,
    this.value,
    this.secondary,
    this.source,
    this.status = HealthStatus.unknown,
  });

  final HealthMetric metric;

  /// Уже отформатированное значение (например "72" или "120/80").
  final String displayValue;

  /// Числовое значение для оценки нормы (для давления — систолическое).
  final double? value;

  /// Доп. числовое значение (для давления — диастолическое).
  final double? secondary;

  /// Время измерения (конец интервала).
  final DateTime time;

  /// Откуда пришли данные (хранилище здоровья, кольцо и т.д.), если известно.
  final MetricSource? source;

  /// Оценка по нормам, рассчитанная на бэкенде.
  final HealthStatus status;
}

/// Из двух чтений выбирает более свежее по времени измерения; null проигрывает
/// всегда, при равенстве побеждает [b] (живой источник передают вторым).
MetricReading? preferFresher(MetricReading? a, MetricReading? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.time.isAfter(b.time) ? a : b;
}
