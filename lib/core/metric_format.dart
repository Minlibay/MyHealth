import 'health_metric.dart';

/// Единое форматирование значения показателя для отображения.
/// Для давления: "120/80".
String formatMetricDisplay(HealthMetric metric, double value, double? secondary) {
  String n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  if (metric == HealthMetric.bloodPressure && secondary != null) {
    return '${n(value)}/${n(secondary)}';
  }
  return n(value);
}
