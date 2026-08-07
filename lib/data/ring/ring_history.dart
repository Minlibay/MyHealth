import '../../core/health_metric.dart';
import '../../core/metric_source.dart';
import '../metric_sample.dart';
import '../sleep_session.dart';

/// История, накопленная кольцом: точки показателей + сессии сна с фазами.
class RingHistory {
  RingHistory({
    Map<HealthMetric, List<MetricSample>>? samples,
    List<SleepSessionModel>? sleepSessions,
  })  : samples = samples ?? {},
        sleepSessions = sleepSessions ?? [];

  final Map<HealthMetric, List<MetricSample>> samples;
  final List<SleepSessionModel> sleepSessions;

  /// Сырые счётчики записей по типам истории (диагностика синхронизации).
  final Map<String, int> rawCounts = {};

  /// Оценки риска апноэ по ночам: 0/1 — низкий, 2 — умеренный, 3 — высокий.
  final List<({DateTime time, int risk})> osaRisks = [];

  /// Ключи первой записи каждого типа — диагностика форматов SDK
  /// (имена полей на Android и iOS различаются).
  final Map<String, String> sampleKeys = {};

  bool get isEmpty =>
      sleepSessions.isEmpty && samples.values.every((l) => l.isEmpty);

  int get totalRecords =>
      sleepSessions.length +
      samples.values.fold(0, (acc, l) => acc + l.length);
}

/// Собирает [RingHistory] из сырых записей нативного слоя.
/// Записи — плоские мапы строка→строка с ключами SDK; имена немного
/// различаются между Android- и iOS-версиями SDK, поэтому у каждого поля
/// список ключей-кандидатов.
class RingHistoryBuilder {
  RingHistoryBuilder({this.source = MetricSource.ring});

  /// Источник для всех записей (кольцо/браслет + имя устройства).
  final MetricSource source;

  final _history = RingHistory();

  RingHistory build() {
    for (final list in _history.samples.values) {
      list.sort((a, b) => a.time.compareTo(b.time));
    }
    _history.sleepSessions.sort((a, b) => b.start.compareTo(a.start));
    _history.osaRisks.sort((a, b) => b.time.compareTo(a.time));
    return _history;
  }

  /// Кандидаты ключей температуры: Android/iOS SDK используют разные имена.
  static const _tempKeys = [
    'temperature',
    'Temperature',
    'temp',
    'TempData',
    'axillaryTemperature',
    'Final_temperature_value',
  ];

  void addRecords(String kind, List<Map<String, String?>> records) {
    _history.rawCounts.update(kind, (v) => v + records.length,
        ifAbsent: () => records.length);
    if (records.isNotEmpty && !_history.sampleKeys.containsKey(kind)) {
      _history.sampleKeys[kind] = records.first.keys.join(',');
    }
    for (final r in records) {
      switch (kind) {
        case 'activity':
          _addActivity(r);
        case 'sleep':
          _addSleep(r);
        case 'dynamicHr':
          _addDynamicHr(r);
        case 'staticHr':
          _addSample(r, HealthMetric.heartRate, ['onceHeartValue', 'singleHR']);
        case 'hrv':
          _addSample(r, HealthMetric.hrv, ['hrv', 'HRV']);
        case 'spo2':
          _addSample(r, HealthMetric.bloodOxygen, ['Blood_oxygen', 'spo2', 'Sp02']);
        case 'temperature' || 'sleepTemperature':
          // Кожная температура: отбрасываем нули и мусор вне 30–43 °C.
          _addSample(r, HealthMetric.bodyTemperature, _tempKeys,
              min: 30, max: 43);
        case 'osa':
          _addOsa(r);
      }
    }
  }

  void _addOsa(Map<String, String?> r) {
    final time = _date(r);
    final risk = int.tryParse(r['osaRick'] ?? r['osaRisk'] ?? '');
    // 16 — «нет результата» по документации SDK.
    if (time == null || risk == null || risk > 3) return;
    _history.osaRisks.add((time: time, risk: risk));
  }

  // --- Разбор полей ---

  static double? _num(Map<String, String?> r, List<String> keys) {
    for (final k in keys) {
      final v = double.tryParse(r[k] ?? '');
      if (v != null) return v;
    }
    return null;
  }

  /// Даты SDK: "2026.07.10 23:15:00" или "2026-07-10 23:15:00" (или без времени).
  static DateTime? _date(Map<String, String?> r) {
    final raw = r['date'];
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.replaceAll('.', '-').replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  void _add(HealthMetric metric, MetricSample sample) =>
      _history.samples.putIfAbsent(metric, () => []).add(sample);

  void _addSample(
      Map<String, String?> r, HealthMetric metric, List<String> keys,
      {double min = 0, double? max}) {
    final time = _date(r);
    final value = _num(r, keys);
    if (time == null || value == null || value <= min) return;
    if (max != null && value > max) return;
    _add(metric,
        MetricSample(time: time, value: value, source: source));
  }

  /// Суточные итоги активности: шаги, калории, дистанция (метры → км).
  void _addActivity(Map<String, String?> r) {
    final time = _date(r);
    if (time == null) return;
    final steps = _num(r, ['step', 'steps']);
    final calories = _num(r, ['calories']);
    final distance = _num(r, ['distance']);
    if (steps != null && steps > 0) {
      _add(HealthMetric.steps,
          MetricSample(time: time, value: steps, source: source));
    }
    if (calories != null && calories > 0) {
      _add(HealthMetric.activeEnergy,
          MetricSample(time: time, value: calories, source: source));
    }
    if (distance != null && distance > 0) {
      // SDK отдаёт километры с двумя знаками (value/100 от сырых сотен метров).
      _add(HealthMetric.distance,
          MetricSample(time: time, value: distance, source: source));
    }
  }

  /// Непрерывный пульс: массив значений на запись — усредняем в одну точку
  /// (точная сетка времени внутри записи в SDK не документирована).
  void _addDynamicHr(Map<String, String?> r) {
    final time = _date(r);
    if (time == null) return;
    final raw = r['arrayDynamicHR'] ?? r['arrayContinuousHR'] ?? r['arrayHR'];
    if (raw == null || raw.isEmpty) return;
    final values = raw
        .split(RegExp(r'[,\s]+'))
        .map(double.tryParse)
        .whereType<double>()
        .where((v) => v > 20 && v < 250)
        .toList();
    if (values.isEmpty) return;
    final avg = values.reduce((a, b) => a + b) / values.length;
    _add(
        HealthMetric.heartRate,
        MetricSample(
            time: time,
            value: double.parse(avg.toStringAsFixed(0)),
            source: source));
  }

  /// Кодировка фаз в arraySleepQuality (конвенция Jstyle X3):
  /// 1 = глубокий, 2 = лёгкий, 3 = REM, 4 = бодрствование, 0 = нет данных.
  /// Требует подтверждения на устройстве — маппинг не описан в SDK.
  static const _stageByCode = {
    1: SleepStageType.deep,
    2: SleepStageType.light,
    3: SleepStageType.rem,
    4: SleepStageType.awake,
  };

  void _addSleep(Map<String, String?> r) {
    final start = _date(r);
    if (start == null) return;
    var raw = r['arraySleepQuality'] ??
        r['arraySleepData_perMinute'] ??
        r['arraySleepData_per2Minutes'];
    // iOS-SDK называет поля иначе — ищем любой массив кодов фаз
    // (список небольших чисел в поле со «sleep» в имени).
    raw ??= r.entries
        .where((e) =>
            e.key.toLowerCase().contains('sleep') &&
            (e.value?.contains(' ') ?? false) &&
            e.value!
                .split(RegExp(r'[,\s]+'))
                .every((t) => int.tryParse(t) != null))
        .map((e) => e.value)
        .firstOrNull;
    if (raw == null || raw.isEmpty) return;
    final unitMinutes =
        int.tryParse(r['sleepUnitLength'] ?? '') ?? 5; // по умолчанию 5-мин сетка
    final codes = raw
        .split(RegExp(r'[,\s]+'))
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    if (codes.isEmpty) return;

    // Склеиваем последовательные одинаковые фазы в сегменты.
    final stages = <SleepStage>[];
    var cursor = start;
    SleepStageType? currentStage;
    DateTime? segmentStart;
    for (final code in codes) {
      final stage = _stageByCode[code];
      if (stage != currentStage) {
        if (currentStage != null && segmentStart != null) {
          stages.add(SleepStage(
              stage: currentStage, start: segmentStart, end: cursor));
        }
        currentStage = stage;
        segmentStart = cursor;
      }
      cursor = cursor.add(Duration(minutes: unitMinutes));
    }
    if (currentStage != null && segmentStart != null) {
      stages.add(
          SleepStage(stage: currentStage, start: segmentStart, end: cursor));
    }
    if (stages.isEmpty) return;

    _history.sleepSessions.add(SleepSessionModel(
      start: start,
      end: cursor,
      stages: stages,
      source: source,
    ));
  }
}
