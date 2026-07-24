import 'health_metric.dart';

/// Правдоподобность значения показателя — отсекает мусор с трекеров
/// (например, пульс 0 уд/мин от кольца при плохом контакте).
/// Накопительные метрики (шаги, калории, вода, дистанция) допускают 0.
bool isPlausibleValue(HealthMetric metric, double value) {
  switch (metric) {
    case HealthMetric.heartRate:
    case HealthMetric.restingHeartRate:
      return value >= 25 && value <= 260;
    case HealthMetric.bloodOxygen:
      return value >= 50 && value <= 100;
    case HealthMetric.respiratoryRate:
      return value >= 3 && value <= 60;
    case HealthMetric.bodyTemperature:
      return value >= 30 && value <= 45;
    case HealthMetric.hrv:
      return value > 0 && value < 400;
    case HealthMetric.bloodPressure:
      return value >= 40 && value <= 300;
    case HealthMetric.bloodGlucose:
      return value > 0.5 && value < 40;
    case HealthMetric.weight:
      return value > 2 && value < 400;
    case HealthMetric.height:
      return value > 30 && value < 260;
    case HealthMetric.bodyFat:
      return value > 0 && value <= 100;
    case HealthMetric.sleep:
      return value > 0 && value <= 24;
    // Накопительные и прочие — 0 допустим, отсекаем только отрицательные.
    case HealthMetric.steps:
    case HealthMetric.distance:
    case HealthMetric.water:
    case HealthMetric.activeEnergy:
    case HealthMetric.dietaryEnergy:
      return value >= 0;
  }
}
