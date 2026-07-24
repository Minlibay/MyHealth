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
    case HealthMetric.walkingHeartRate:
      return value >= 25 && value <= 260;
    case HealthMetric.bloodPressure:
      return value >= 40 && value <= 300;
    case HealthMetric.leanBodyMass:
    case HealthMetric.bodyWater:
      return value > 2 && value < 400;
    case HealthMetric.bmi:
      return value > 5 && value < 100;
    case HealthMetric.waist:
      return value > 20 && value < 300;
    case HealthMetric.walkingSpeed:
      return value > 0 && value < 20;
    case HealthMetric.skinTemperature:
      return value >= 20 && value <= 45;
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
    case HealthMetric.flightsClimbed:
    case HealthMetric.basalEnergy:
    case HealthMetric.totalCalories:
    case HealthMetric.exerciseTime:
    case HealthMetric.standTime:
    case HealthMetric.moveMinutes:
    case HealthMetric.mindfulness:
    case HealthMetric.distanceCycling:
    case HealthMetric.distanceSwimming:
    case HealthMetric.carbs:
    case HealthMetric.protein:
    case HealthMetric.fat:
      return value >= 0;
  }
}
