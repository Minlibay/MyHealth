import 'dart:math';

import '../core/health_metric.dart';
import 'health_repository.dart';
import 'metric_reading.dart';
import 'metric_sample.dart';

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
          source: 'Demo Device',
        );

    final steps = 6000 + _rnd.nextInt(3000);
    final hr = 64 + _rnd.nextInt(20);
    final sys = 118 + _rnd.nextInt(8);
    final dia = 76 + _rnd.nextInt(6);
    final weight = 74 + _rnd.nextInt(9) / 10;
    final sleep = 7 + _rnd.nextInt(9) / 10;
    final glucose = 5 + _rnd.nextInt(9) / 10;
    final spo2 = 96 + _rnd.nextInt(4);

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
    };

    final now = DateTime.now();
    final samples = <MetricSample>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i, 12);
      final value = base + (_rnd.nextDouble() - 0.5) * spread;
      samples.add(MetricSample(
        time: day,
        value: value,
        // Для давления — диастолическое примерно на 40 ниже систолического.
        secondary: metric == HealthMetric.bloodPressure
            ? value - 42 + (_rnd.nextDouble() - 0.5) * 6
            : null,
      ));
    }
    return samples;
  }

  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 400));
}
