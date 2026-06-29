import 'package:flutter/material.dart';

/// Показатель здоровья, который умеет читать приложение.
///
/// Чистый UI-уровень: НЕ зависит от пакета `health`, чтобы файл можно было
/// компилировать под Web. Маппинг на типы HealthKit/Health Connect живёт
/// только в реальной реализации репозитория (health_service_real.dart).
enum HealthMetric {
  steps(
      title: 'Шаги',
      icon: Icons.directions_walk_rounded,
      unit: 'шагов',
      color: Color(0xFF4F6DF5)),
  heartRate(
      title: 'Пульс',
      icon: Icons.favorite_rounded,
      unit: 'уд/мин',
      color: Color(0xFFF2496B)),
  bloodPressure(
      title: 'Давление',
      icon: Icons.monitor_heart_rounded,
      unit: 'мм рт. ст.',
      color: Color(0xFF8B5CF6)),
  weight(
      title: 'Вес',
      icon: Icons.monitor_weight_rounded,
      unit: 'кг',
      color: Color(0xFF14B8A6)),
  sleep(
      title: 'Сон',
      icon: Icons.bedtime_rounded,
      unit: 'ч',
      color: Color(0xFF6366F1)),
  bloodGlucose(
      title: 'Глюкоза',
      icon: Icons.water_drop_rounded,
      unit: 'ммоль/л',
      color: Color(0xFFFB923C)),
  bloodOxygen(
      title: 'SpO₂',
      icon: Icons.air_rounded,
      unit: '%',
      color: Color(0xFF06B6D4));

  const HealthMetric({
    required this.title,
    required this.icon,
    required this.unit,
    required this.color,
  });

  final String title;
  final IconData icon;
  final String unit;

  /// Акцентный цвет показателя (карточки, графики).
  final Color color;
}
