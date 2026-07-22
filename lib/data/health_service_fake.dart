import 'dart:math';

import '../core/health_metric.dart';
import '../core/metric_source.dart';
import 'health_repository.dart';
import 'metric_reading.dart';
import 'metric_sample.dart';
import 'workout.dart';

/// Фабрика для условного импорта (см. health_repository_factory.dart).
HealthRepository createHealthRepository() => FakeHealthService();

/// Фейковый источник данных для Web и разработки UI.
/// Возвращает правдоподобные значения и имитирует flow разрешений.
class FakeHealthService implements HealthRepository {
  final _rnd = Random();

  @override
  Future<HealthAvailability> checkAvailability() async {
    await _delay();
    return HealthAvailability.available;
  }

  @override
  Future<void> installHealthConnect() async {}

  @override
  Future<bool> requestPermissions() async {
    await _delay();
    return true;
  }

  @override
  Future<bool?> hasPermissions() async => true;

  @override
  Future<void> revokePermissions() async {}

  @override
  Future<Map<HealthMetric, MetricReading?>> fetchLatestAll({int days = 7}) async {
    await _delay();
    final now = DateTime.now();

    MetricReading r(HealthMetric m, String display, double value, Duration ago,
            {double? secondary}) =>
        MetricReading(
          metric: m,
          displayValue: display,
          value: value,
          secondary: secondary,
          time: now.subtract(ago),
          source: MetricSource.demo,
        );

    final steps = 6000 + _rnd.nextInt(3000);
    final hr = 64 + _rnd.nextInt(20);
    final sys = 118 + _rnd.nextInt(8);
    final dia = 76 + _rnd.nextInt(6);
    final weight = 74 + _rnd.nextInt(9) / 10;
    final sleep = 7 + _rnd.nextInt(9) / 10;
    final glucose = 5 + _rnd.nextInt(9) / 10;
    final spo2 = 96 + _rnd.nextInt(4);
    final energy = 350 + _rnd.nextInt(250);
    final dist = 4 + _rnd.nextInt(40) / 10;
    final waterL = 1 + _rnd.nextInt(15) / 10;
    final temp = 36.4 + _rnd.nextInt(5) / 10;
    final resp = 14 + _rnd.nextInt(4);
    final rhr = 56 + _rnd.nextInt(10);
    final hrv = 35 + _rnd.nextInt(40);
    final fat = 18 + _rnd.nextInt(80) / 10;
    final heightCm = 176.0;
    final dietary = 1400 + _rnd.nextInt(900);

    return {
      HealthMetric.steps:
          r(HealthMetric.steps, '$steps', steps.toDouble(), const Duration(minutes: 5)),
      HealthMetric.heartRate:
          r(HealthMetric.heartRate, '$hr', hr.toDouble(), const Duration(minutes: 12)),
      HealthMetric.bloodPressure: r(HealthMetric.bloodPressure, '$sys/$dia',
          sys.toDouble(), const Duration(hours: 3),
          secondary: dia.toDouble()),
      HealthMetric.weight: r(HealthMetric.weight, weight.toStringAsFixed(1),
          weight, const Duration(hours: 20)),
      HealthMetric.sleep: r(HealthMetric.sleep, sleep.toStringAsFixed(1), sleep,
          const Duration(hours: 8)),
      HealthMetric.bloodGlucose: r(HealthMetric.bloodGlucose,
          glucose.toStringAsFixed(1), glucose, const Duration(hours: 2)),
      HealthMetric.bloodOxygen: r(HealthMetric.bloodOxygen, '$spo2',
          spo2.toDouble(), const Duration(minutes: 40)),
      HealthMetric.activeEnergy: r(HealthMetric.activeEnergy, '$energy',
          energy.toDouble(), const Duration(minutes: 10)),
      HealthMetric.distance: r(HealthMetric.distance, dist.toStringAsFixed(1),
          dist, const Duration(minutes: 10)),
      HealthMetric.water: r(HealthMetric.water, waterL.toStringAsFixed(1),
          waterL, const Duration(hours: 1)),
      HealthMetric.bodyTemperature: r(HealthMetric.bodyTemperature,
          temp.toStringAsFixed(1), temp, const Duration(hours: 6)),
      HealthMetric.respiratoryRate: r(HealthMetric.respiratoryRate, '$resp',
          resp.toDouble(), const Duration(hours: 8)),
      HealthMetric.restingHeartRate: r(HealthMetric.restingHeartRate, '$rhr',
          rhr.toDouble(), const Duration(hours: 8)),
      HealthMetric.hrv: r(HealthMetric.hrv, '$hrv', hrv.toDouble(),
          const Duration(hours: 8)),
      HealthMetric.bodyFat: r(HealthMetric.bodyFat, fat.toStringAsFixed(1),
          fat, const Duration(days: 2)),
      HealthMetric.height: r(HealthMetric.height, heightCm.toStringAsFixed(0),
          heightCm, const Duration(days: 30)),
      HealthMetric.dietaryEnergy: r(HealthMetric.dietaryEnergy, '$dietary',
          dietary.toDouble(), const Duration(hours: 3)),
    };
  }

  @override
  Future<List<MetricSample>> fetchSeries(HealthMetric metric, {int days = 7}) async {
    await _delay();
    // База и разброс значений для правдоподобной генерации.
    final (base, spread) = switch (metric) {
      HealthMetric.steps => (7500.0, 4000.0),
      HealthMetric.heartRate => (72.0, 18.0),
      HealthMetric.bloodPressure => (122.0, 10.0),
      HealthMetric.weight => (74.5, 1.2),
      HealthMetric.sleep => (7.2, 1.8),
      HealthMetric.bloodGlucose => (5.4, 1.0),
      HealthMetric.bloodOxygen => (98.0, 2.0),
      HealthMetric.activeEnergy => (450.0, 250.0),
      HealthMetric.distance => (5.5, 3.0),
      HealthMetric.water => (1.6, 0.8),
      HealthMetric.bodyTemperature => (36.6, 0.5),
      HealthMetric.respiratoryRate => (15.0, 3.0),
      HealthMetric.restingHeartRate => (60.0, 8.0),
      HealthMetric.hrv => (55.0, 25.0),
      HealthMetric.bodyFat => (21.0, 3.0),
      HealthMetric.height => (176.0, 0.0),
      HealthMetric.dietaryEnergy => (1900.0, 700.0),
    };

    final now = DateTime.now();
    final samples = <MetricSample>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i, 12);
      final value = base + (_rnd.nextDouble() - 0.5) * spread;
      samples.add(MetricSample(
        time: day,
        value: value,
        source: MetricSource.demo,
        // Для давления — диастолическое примерно на 40 ниже систолического.
        secondary: metric == HealthMetric.bloodPressure
            ? value - 42 + (_rnd.nextDouble() - 0.5) * 6
            : null,
      ));
    }
    return samples;
  }

  @override
  Future<List<Workout>> fetchWorkouts({int days = 30}) async {
    await _delay();
    const types = ['RUNNING', 'WALKING', 'YOGA', 'STRENGTH_TRAINING', 'BIKING'];
    final now = DateTime.now();
    final workouts = <Workout>[];
    for (var i = 0; i < days; i++) {
      if (_rnd.nextDouble() > 0.6) continue; // тренировки не каждый день
      final start = DateTime(now.year, now.month, now.day - i, 8 + _rnd.nextInt(11));
      final minutes = 25 + _rnd.nextInt(60);
      workouts.add(Workout(
        activityType: types[_rnd.nextInt(types.length)],
        start: start,
        end: start.add(Duration(minutes: minutes)),
        energyKcal: (minutes * (5 + _rnd.nextInt(5))).toDouble(),
        distanceMeters:
            _rnd.nextBool() ? (minutes * (80 + _rnd.nextInt(100))).toDouble() : null,
        source: MetricSource.demo,
      ));
    }
    return workouts;
  }

  @override
  Future<List<MetricDiagnostic>> diagnostics({int days = 7}) async {
    await _delay();
    return [
      for (final m in HealthMetric.values)
        MetricDiagnostic(
          metric: m,
          available: true,
          recordCount: 20 + _rnd.nextInt(80),
          sources: const ['Demo'],
        ),
    ];
  }

  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 400));
}
