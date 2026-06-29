import 'package:flutter/material.dart';

import 'health_metric.dart';

/// Оценка значения относительно типичной нормы.
/// Не медицинский диагноз — только визуальный ориентир.
enum HealthStatus {
  ok(label: 'Норма', color: Color(0xFF16A34A)),
  warn(label: 'Погранично', color: Color(0xFFD97706)),
  alert(label: 'Вне нормы', color: Color(0xFFDC2626)),
  unknown(label: '', color: Color(0xFF9E9E9E));

  const HealthStatus({required this.label, required this.color});

  final String label;
  final Color color;

  bool get isMeaningful => this != HealthStatus.unknown;
}

/// Классифицирует значение показателя по ориентировочным нормам для взрослых.
/// Для давления [value] = систолическое, [secondary] = диастолическое.
HealthStatus statusFor(HealthMetric metric, double? value, [double? secondary]) {
  if (value == null) return HealthStatus.unknown;

  switch (metric) {
    case HealthMetric.heartRate:
      if (value >= 120 || value < 45) return HealthStatus.alert;
      if (value > 100 || value < 55) return HealthStatus.warn;
      return HealthStatus.ok;

    case HealthMetric.bloodPressure:
      final sys = value;
      final dia = secondary ?? 0;
      if (sys >= 140 || dia >= 90 || sys < 90) return HealthStatus.alert;
      if (sys >= 130 || dia >= 85) return HealthStatus.warn;
      return HealthStatus.ok;

    case HealthMetric.bloodOxygen:
      if (value < 90) return HealthStatus.alert;
      if (value < 95) return HealthStatus.warn;
      return HealthStatus.ok;

    case HealthMetric.bloodGlucose:
      if (value >= 7.0 || value < 3.9) return HealthStatus.alert;
      if (value >= 5.6) return HealthStatus.warn;
      return HealthStatus.ok;

    case HealthMetric.sleep:
      if (value < 5 || value > 10) return HealthStatus.warn;
      return HealthStatus.ok;

    // Для шагов и веса нет универсальной «нормы» — не оцениваем.
    case HealthMetric.steps:
    case HealthMetric.weight:
      return HealthStatus.unknown;
  }
}
