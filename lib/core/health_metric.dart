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
      color: Color(0xFF06B6D4)),
  activeEnergy(
      title: 'Активные калории',
      icon: Icons.local_fire_department_rounded,
      unit: 'ккал',
      color: Color(0xFFF97316)),
  distance(
      title: 'Дистанция',
      icon: Icons.route_rounded,
      unit: 'км',
      color: Color(0xFF22C55E)),
  water(
      title: 'Вода',
      icon: Icons.local_drink_rounded,
      unit: 'л',
      color: Color(0xFF0EA5E9)),
  bodyTemperature(
      title: 'Температура',
      icon: Icons.thermostat_rounded,
      unit: '°C',
      color: Color(0xFFEF4444)),
  respiratoryRate(
      title: 'Дыхание',
      icon: Icons.waves_rounded,
      unit: 'вд/мин',
      color: Color(0xFF38BDF8)),
  restingHeartRate(
      title: 'Пульс в покое',
      icon: Icons.favorite_border_rounded,
      unit: 'уд/мин',
      color: Color(0xFFE11D48)),
  hrv(
      title: 'HRV',
      icon: Icons.stacked_line_chart_rounded,
      unit: 'мс',
      color: Color(0xFFA855F7)),
  bodyFat(
      title: 'Жир в теле',
      icon: Icons.pie_chart_rounded,
      unit: '%',
      color: Color(0xFFEAB308)),
  height(
      title: 'Рост',
      icon: Icons.height_rounded,
      unit: 'см',
      color: Color(0xFF64748B)),
  dietaryEnergy(
      title: 'Питание',
      icon: Icons.restaurant_rounded,
      unit: 'ккал',
      color: Color(0xFF84CC16)),
  flightsClimbed(
      title: 'Этажи',
      icon: Icons.stairs_rounded,
      unit: 'этажей',
      color: Color(0xFF10B981)),
  basalEnergy(
      title: 'Калории покоя',
      icon: Icons.local_fire_department_outlined,
      unit: 'ккал',
      color: Color(0xFFFB7185)),
  totalCalories(
      title: 'Всего калорий',
      icon: Icons.whatshot_rounded,
      unit: 'ккал',
      color: Color(0xFFF43F5E)),
  exerciseTime(
      title: 'Минуты тренировок',
      icon: Icons.timer_rounded,
      unit: 'мин',
      color: Color(0xFF34D399)),
  standTime(
      title: 'Время стоя',
      icon: Icons.accessibility_new_rounded,
      unit: 'мин',
      color: Color(0xFF2DD4BF)),
  moveMinutes(
      title: 'Минуты движения',
      icon: Icons.transfer_within_a_station_rounded,
      unit: 'мин',
      color: Color(0xFF4ADE80)),
  mindfulness(
      title: 'Осознанность',
      icon: Icons.self_improvement_rounded,
      unit: 'мин',
      color: Color(0xFF818CF8)),
  distanceCycling(
      title: 'Велодистанция',
      icon: Icons.directions_bike_rounded,
      unit: 'км',
      color: Color(0xFF16A34A)),
  distanceSwimming(
      title: 'Плавание',
      icon: Icons.pool_rounded,
      unit: 'км',
      color: Color(0xFF0891B2)),
  walkingHeartRate(
      title: 'Пульс при ходьбе',
      icon: Icons.monitor_heart_outlined,
      unit: 'уд/мин',
      color: Color(0xFFFB7185)),
  leanBodyMass(
      title: 'Мышечная масса',
      icon: Icons.fitness_center_rounded,
      unit: 'кг',
      color: Color(0xFF14B8A6)),
  bmi(
      title: 'ИМТ',
      icon: Icons.straighten_rounded,
      unit: '',
      color: Color(0xFF64748B)),
  waist(
      title: 'Талия',
      icon: Icons.straighten_rounded,
      unit: 'см',
      color: Color(0xFF94A3B8)),
  bodyWater(
      title: 'Вода в теле',
      icon: Icons.water_drop_outlined,
      unit: 'кг',
      color: Color(0xFF38BDF8)),
  walkingSpeed(
      title: 'Скорость ходьбы',
      icon: Icons.speed_rounded,
      unit: 'км/ч',
      color: Color(0xFF60A5FA)),
  carbs(
      title: 'Углеводы',
      icon: Icons.bakery_dining_rounded,
      unit: 'г',
      color: Color(0xFFF59E0B)),
  protein(
      title: 'Белки',
      icon: Icons.egg_rounded,
      unit: 'г',
      color: Color(0xFFEF4444)),
  fat(
      title: 'Жиры',
      icon: Icons.opacity_rounded,
      unit: 'г',
      color: Color(0xFFEAB308)),
  skinTemperature(
      title: 'Температура кожи',
      icon: Icons.device_thermostat_rounded,
      unit: '°C',
      color: Color(0xFFF97316));

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
