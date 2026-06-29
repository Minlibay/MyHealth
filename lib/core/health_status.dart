import 'package:flutter/material.dart';

/// Оценка значения относительно нормы. Сам расчёт выполняется на бэкенде (C#);
/// клиент только отображает присланный статус. Не медицинский диагноз.
enum HealthStatus {
  ok(label: 'Норма', color: Color(0xFF16A34A)),
  warn(label: 'Погранично', color: Color(0xFFD97706)),
  alert(label: 'Вне нормы', color: Color(0xFFDC2626)),
  unknown(label: '', color: Color(0xFF9E9E9E));

  const HealthStatus({required this.label, required this.color});

  final String label;
  final Color color;

  bool get isMeaningful => this != HealthStatus.unknown;

  /// Парсит значение enum с бэкенда ("Ok"/"Warn"/"Alert"/"Unknown").
  static HealthStatus fromApi(String? name) {
    switch (name?.toLowerCase()) {
      case 'ok':
        return HealthStatus.ok;
      case 'warn':
        return HealthStatus.warn;
      case 'alert':
        return HealthStatus.alert;
      default:
        return HealthStatus.unknown;
    }
  }
}
