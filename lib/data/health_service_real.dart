import 'dart:io' show Platform;

import 'package:health/health.dart';

import '../core/health_metric.dart';
import '../core/metric_source.dart';
import 'health_repository.dart';
import 'metric_reading.dart';
import 'metric_sample.dart';
import 'workout.dart';

/// Фабрика для условного импорта (см. health_repository_factory.dart).
HealthRepository createHealthRepository() => RealHealthService();

/// Типы сна различаются по платформам: SLEEP_SESSION есть только в
/// Health Connect, а HealthKit пишет сон сегментами по фазам
/// (SLEEP_LIGHT здесь = asleepCore). SLEEP_ASLEEP и SLEEP_SESSION вместе
/// на Android нельзя — сессия уже включает фазы, будет двойной счёт.
final List<HealthDataType> _sleepTypes = Platform.isIOS
    ? [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ]
    : [HealthDataType.SLEEP_SESSION];

/// Маппинг показателей приложения на типы HealthKit / Health Connect.
/// Дистанция и HRV имеют разные типы на платформах (SDNN на iOS,
/// RMSSD на Android — значения между платформами не сравниваются напрямую).
final Map<HealthMetric, List<HealthDataType>> _typeMap = {
  HealthMetric.steps: [HealthDataType.STEPS],
  HealthMetric.heartRate: [HealthDataType.HEART_RATE],
  HealthMetric.bloodPressure: [
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  ],
  HealthMetric.weight: [HealthDataType.WEIGHT],
  HealthMetric.sleep: _sleepTypes,
  HealthMetric.bloodGlucose: [HealthDataType.BLOOD_GLUCOSE],
  HealthMetric.bloodOxygen: [HealthDataType.BLOOD_OXYGEN],
  HealthMetric.activeEnergy: [HealthDataType.ACTIVE_ENERGY_BURNED],
  HealthMetric.distance: Platform.isIOS
      ? [HealthDataType.DISTANCE_WALKING_RUNNING]
      : [HealthDataType.DISTANCE_DELTA],
  HealthMetric.water: [HealthDataType.WATER],
  HealthMetric.bodyTemperature: [HealthDataType.BODY_TEMPERATURE],
  HealthMetric.respiratoryRate: [HealthDataType.RESPIRATORY_RATE],
  HealthMetric.restingHeartRate: [HealthDataType.RESTING_HEART_RATE],
  HealthMetric.hrv: Platform.isIOS
      ? [HealthDataType.HEART_RATE_VARIABILITY_SDNN]
      : [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
  HealthMetric.bodyFat: [HealthDataType.BODY_FAT_PERCENTAGE],
  HealthMetric.height: [HealthDataType.HEIGHT],
  // iOS отдаёт калории напрямую, Android — внутри композитной записи
  // NUTRITION (см. _rawNum).
  HealthMetric.dietaryEnergy: Platform.isIOS
      ? [HealthDataType.DIETARY_ENERGY_CONSUMED]
      : [HealthDataType.NUTRITION],
};

/// Накопительные показатели: осмыслена суточная сумма, а не последняя запись.
/// Шаги обрабатываются отдельно через getTotalStepsInInterval.
const Set<HealthMetric> _dailySumMetrics = {
  HealthMetric.activeEnergy,
  HealthMetric.distance,
  HealthMetric.water,
  HealthMetric.dietaryEnergy,
};

/// Приведение сырого значения к единицам приложения:
/// метры → км/см, доля жира на iOS → проценты.
double _convertValue(HealthMetric metric, double v) => switch (metric) {
      HealthMetric.distance => v / 1000,
      HealthMetric.height => v * 100,
      // HealthKit может отдавать долю (0.18 = 18%), Health Connect — проценты.
      HealthMetric.bodyFat => v <= 1 ? v * 100 : v,
      _ => v,
    };

final List<HealthDataType> _allTypes = {
  for (final list in _typeMap.values) ...list,
  HealthDataType.WORKOUT,
}.toList();

/// Хранилище платформы: Apple Health бывает только на iOS,
/// Health Connect — только на Android.
final MetricSourceType _storeType =
    Platform.isIOS ? MetricSourceType.appleHealth : MetricSourceType.healthConnect;

/// Источник «хранилище платформы + приложение/устройство, записавшее данные».
MetricSource _storeSource([String? detail]) => MetricSource(_storeType, detail);

/// Реальная реализация поверх пакета `health`.
class RealHealthService implements HealthRepository {
  RealHealthService() : _health = Health();

  final Health _health;
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthAvailability> checkAvailability() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return HealthAvailability.unsupported;
    }
    await _ensureConfigured();

    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      switch (status) {
        case HealthConnectSdkStatus.sdkAvailable:
          return HealthAvailability.available;
        case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
          return HealthAvailability.needsUpdate;
        case HealthConnectSdkStatus.sdkUnavailable:
        case null:
          return HealthAvailability.needsInstall;
      }
    }
    return HealthAvailability.available;
  }

  @override
  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Future<bool> requestPermissions() async {
    await _ensureConfigured();
    return _health.requestAuthorization(
      _allTypes,
      permissions: List.filled(_allTypes.length, HealthDataAccess.READ),
    );
  }

  @override
  Future<bool?> hasPermissions() async {
    await _ensureConfigured();
    return _health.hasPermissions(
      _allTypes,
      permissions: List.filled(_allTypes.length, HealthDataAccess.READ),
    );
  }

  @override
  Future<void> revokePermissions() async {
    await _ensureConfigured();
    await _health.revokePermissions();
  }

  @override
  Future<Map<HealthMetric, MetricReading?>> fetchLatestAll({int days = 7}) async {
    await _ensureConfigured();
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));

    final result = <HealthMetric, MetricReading?>{};
    for (final metric in HealthMetric.values) {
      try {
        result[metric] = await _fetchLatest(metric, from, now);
      } catch (_) {
        result[metric] = null;
      }
    }
    return result;
  }

  Future<MetricReading?> _fetchLatest(
    HealthMetric metric,
    DateTime from,
    DateTime to,
  ) async {
    final types = _typeMap[metric]!;

    // Шаги — суммарно за сегодня, а не последняя запись.
    if (metric == HealthMetric.steps) {
      final startOfDay = DateTime(to.year, to.month, to.day);
      final total = await _health.getTotalStepsInInterval(startOfDay, to);
      if (total == null) return null;
      return MetricReading(
          metric: metric,
          displayValue: '$total',
          value: total.toDouble(),
          time: to,
          source: _storeSource());
    }

    // Накопительные показатели — сумма за сегодня.
    if (_dailySumMetrics.contains(metric)) {
      final startOfDay = DateTime(to.year, to.month, to.day);
      final points = await _health.getHealthDataFromTypes(
        types: types,
        startTime: startOfDay,
        endTime: to,
      );
      if (points.isEmpty) return null;
      var total = 0.0;
      for (final p in points) {
        total += _convertValue(metric, _rawNum(p));
      }
      return MetricReading(
        metric: metric,
        displayValue: _fmt(total),
        value: total,
        time: to,
        source: _storeSource(),
      );
    }

    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: from,
      endTime: to,
    );
    if (points.isEmpty) return null;
    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));

    // Давление: последняя пара систолическое/диастолическое.
    if (metric == HealthMetric.bloodPressure) {
      final sys = points.firstWhereOrNull(
        (p) => p.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      );
      final dia = points.firstWhereOrNull(
        (p) => p.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      );
      if (sys == null || dia == null) return null;
      return MetricReading(
        metric: metric,
        displayValue: '${_num(sys)}/${_num(dia)}',
        value: _rawNum(sys),
        secondary: _rawNum(dia),
        time: sys.dateTo,
        source: _storeSource(sys.sourceName),
      );
    }

    final latest = points.first;

    // Сон приходит сегментами в минутах — суммируем последнюю ночь
    // и показываем в часах. Окно 18 часов от конца последнего сегмента
    // покрывает всю ночь, но не захватывает предыдущую (~24 ч назад).
    if (metric == HealthMetric.sleep) {
      final nightStart = latest.dateTo.subtract(const Duration(hours: 18));
      var minutes = 0.0;
      for (final p in points) {
        if (!p.dateTo.isBefore(nightStart)) minutes += _rawNum(p);
      }
      final hours = minutes / 60;
      return MetricReading(
        metric: metric,
        displayValue: hours.toStringAsFixed(1),
        value: hours,
        time: latest.dateTo,
        source: _storeSource(latest.sourceName),
      );
    }

    final value = _convertValue(metric, _rawNum(latest));
    return MetricReading(
      metric: metric,
      displayValue: _fmt(value),
      value: value,
      time: latest.dateTo,
      source: _storeSource(latest.sourceName),
    );
  }

  @override
  Future<List<MetricSample>> fetchSeries(HealthMetric metric, {int days = 7}) async {
    await _ensureConfigured();
    final now = DateTime.now();

    // Шаги — суммарно по дням.
    if (metric == HealthMetric.steps) {
      final samples = <MetricSample>[];
      for (var i = days - 1; i >= 0; i--) {
        final start = DateTime(now.year, now.month, now.day - i);
        final end = start.add(const Duration(days: 1));
        final total = await _health.getTotalStepsInInterval(start, end);
        samples.add(MetricSample(
            time: start, value: (total ?? 0).toDouble(), source: _storeSource()));
      }
      return samples;
    }

    final from = now.subtract(Duration(days: days));
    final points = await _health.getHealthDataFromTypes(
      types: _typeMap[metric]!,
      startTime: from,
      endTime: now,
    );
    points.sort((a, b) => a.dateTo.compareTo(b.dateTo));

    // Давление: систолическое = value, ближайшее по времени диастолическое = secondary.
    if (metric == HealthMetric.bloodPressure) {
      final sys = points
          .where((p) => p.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC)
          .toList();
      final dia = points
          .where((p) => p.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC)
          .toList();
      return [
        for (final s in sys)
          MetricSample(
            time: s.dateTo,
            value: _rawNum(s),
            source: _storeSource(s.sourceName),
            secondary: dia.isEmpty
                ? null
                : _rawNum(dia.reduce((a, b) =>
                    (a.dateTo.difference(s.dateTo)).abs() <
                            (b.dateTo.difference(s.dateTo)).abs()
                        ? a
                        : b)),
          ),
      ];
    }

    // Накопительные показатели: суммы по календарным дням.
    if (_dailySumMetrics.contains(metric)) {
      final byDay = <DateTime, double>{};
      for (final p in points) {
        final day = DateTime(p.dateTo.year, p.dateTo.month, p.dateTo.day);
        byDay[day] = (byDay[day] ?? 0) + _convertValue(metric, _rawNum(p));
      }
      final sortedDays = byDay.keys.toList()..sort();
      return [
        for (final d in sortedDays)
          MetricSample(time: d, value: byDay[d]!, source: _storeSource()),
      ];
    }

    // Сон: суммируем сегменты по ночам (ночь относим к дате пробуждения),
    // в часах для единообразия с дашбордом.
    if (metric == HealthMetric.sleep) {
      final byDay = <DateTime, double>{};
      for (final p in points) {
        final day = DateTime(p.dateTo.year, p.dateTo.month, p.dateTo.day);
        byDay[day] = (byDay[day] ?? 0) + _rawNum(p);
      }
      final sortedDays = byDay.keys.toList()..sort();
      return [
        for (final d in sortedDays)
          MetricSample(time: d, value: byDay[d]! / 60, source: _storeSource()),
      ];
    }

    return [
      for (final p in points)
        MetricSample(
            time: p.dateTo,
            value: _convertValue(metric, _rawNum(p)),
            source: _storeSource(p.sourceName)),
    ];
  }

  @override
  Future<List<Workout>> fetchWorkouts({int days = 30}) async {
    await _ensureConfigured();
    final now = DateTime.now();
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: now.subtract(Duration(days: days)),
      endTime: now,
    );
    final workouts = <Workout>[];
    for (final p in points) {
      final v = p.value;
      if (v is! WorkoutHealthValue) continue;
      workouts.add(Workout(
        activityType: v.workoutActivityType.name,
        start: p.dateFrom,
        end: p.dateTo,
        energyKcal: v.totalEnergyBurned?.toDouble(),
        distanceMeters: v.totalDistance?.toDouble(),
        source: _storeSource(p.sourceName),
      ));
    }
    workouts.sort((a, b) => b.start.compareTo(a.start));
    return workouts;
  }

  @override
  Future<List<MetricDiagnostic>> diagnostics({int days = 7}) async {
    await _ensureConfigured();
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));

    final result = <MetricDiagnostic>[];
    for (final metric in HealthMetric.values) {
      final types = _typeMap[metric]!;
      // Тип доступен на платформе (иначе чтение бросает исключение).
      final available = types.every(_health.isDataTypeAvailable);
      var count = 0;
      final sources = <String>{};
      if (available) {
        try {
          final points = await _health.getHealthDataFromTypes(
            types: types,
            startTime: from,
            endTime: now,
          );
          count = points.length;
          for (final p in points) {
            if (p.sourceName.isNotEmpty) sources.add(p.sourceName);
          }
        } catch (_) {
          // Нет разрешения на этот тип — оставляем count=0.
        }
      }
      result.add(MetricDiagnostic(
        metric: metric,
        available: available,
        recordCount: count,
        sources: sources.toList()..sort(),
      ));
    }
    return result;
  }

  String _num(HealthDataPoint p) => _fmt(_rawNum(p));

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  double _rawNum(HealthDataPoint p) {
    final value = p.value;
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    // Android: приём пищи — композитная запись, калории внутри.
    if (value is NutritionHealthValue) return value.calories ?? 0;
    return 0;
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
