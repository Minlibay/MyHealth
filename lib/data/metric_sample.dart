import '../core/metric_source.dart';

/// Одна точка истории показателя.
/// [secondary] используется для давления (систолическое = value, диастолическое = secondary).
class MetricSample {
  const MetricSample({
    required this.time,
    required this.value,
    this.secondary,
    this.source,
  });

  final DateTime time;
  final double value;
  final double? secondary;

  /// Откуда получено измерение (для атрибуции при выгрузке на сервер).
  final MetricSource? source;
}
