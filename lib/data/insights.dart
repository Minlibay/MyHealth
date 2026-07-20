import '../core/health_metric.dart';
import 'api/metrics_api.dart';

/// Персональная базовая линия показателя (среднее и σ за 30 дней).
class Baseline {
  const Baseline({
    required this.metric,
    required this.avg,
    required this.stdDev,
    this.current,
    this.deviationPct,
  });

  final HealthMetric metric;
  final double avg;
  final double stdDev;
  final double? current;
  final double? deviationPct;
}

/// Тренд: среднее этой недели против прошлой.
class Trend {
  const Trend({
    required this.metric,
    required this.thisWeekAvg,
    required this.lastWeekAvg,
    required this.changePct,
    required this.direction,
  });

  final HealthMetric metric;
  final double thisWeekAvg;
  final double lastWeekAvg;
  final double changePct;
  final String direction; // up | down | flat
}

class Anomaly {
  const Anomaly({
    required this.metric,
    required this.message,
    required this.severity,
  });

  final HealthMetric metric;
  final String message;
  final String severity; // warn | alert
}

/// Фактор скора: из чего он сложился.
class ScoreFactor {
  const ScoreFactor({
    required this.name,
    required this.detail,
    required this.impact,
  });

  final String name;
  final String detail;
  final String impact; // positive | negative | neutral
}

/// Один скор 0–100 с объяснением.
class Score {
  const Score({
    required this.key,
    required this.title,
    required this.value,
    this.factors = const [],
  });

  final String key;
  final String title;
  final int value;
  final List<ScoreFactor> factors;

  /// Для «стрессовых» скоров хорошо, когда значение низкое.
  bool get lowerIsBetter =>
      key == 'stress' || key == 'sleepStress' || key == 'inactiveStress';
}

/// Тренировочная нагрузка: острая неделя против хронического среднего.
class TrainingLoad {
  const TrainingLoad({
    required this.acuteLoad,
    required this.chronicLoad,
    this.ratio,
    required this.status,
  });

  final double acuteLoad;
  final double chronicLoad;
  final double? ratio;
  final String status; // low | optimal | high | risky | unknown

  String get statusLabel => switch (status) {
        'low' => 'Недогрузка',
        'optimal' => 'Оптимально',
        'high' => 'Высокая',
        'risky' => 'Риск перегрузки',
        _ => 'Мало данных',
      };
}

/// Ночные показатели из последней сессии сна.
class NightVitals {
  const NightVitals({
    this.restingHr,
    this.restingHrBaseline,
    this.spo2Min,
    this.spo2Dips,
    this.sleepRegularityMinutes,
  });

  /// Пульс покоя за ночь (5-й перцентиль пульса во сне).
  final double? restingHr;

  /// Ваша норма ночного пульса покоя за 30 дней.
  final double? restingHrBaseline;

  final double? spo2Min;
  final int? spo2Dips;

  /// Разброс времени отбоя за 14 дней, минуты (σ).
  final double? sleepRegularityMinutes;

  bool get isEmpty =>
      restingHr == null && spo2Min == null && sleepRegularityMinutes == null;

  factory NightVitals.fromJson(Map<String, dynamic> json) => NightVitals(
        restingHr: (json['restingHr'] as num?)?.toDouble(),
        restingHrBaseline: (json['restingHrBaseline'] as num?)?.toDouble(),
        spo2Min: (json['spo2Min'] as num?)?.toDouble(),
        spo2Dips: (json['spo2Dips'] as num?)?.toInt(),
        sleepRegularityMinutes:
            (json['sleepRegularityMinutes'] as num?)?.toDouble(),
      );
}

/// Точка почасового стресс-таймлайна.
class StressPoint {
  const StressPoint({required this.at, required this.value});
  final DateTime at;
  final int value;
}

/// Недельный отчёт: эта неделя против прошлой.
class WeeklyReport {
  const WeeklyReport({
    required this.trends,
    required this.workoutsThisWeek,
    required this.workoutsLastWeek,
    required this.trimpThisWeek,
    required this.trimpLastWeek,
  });

  final List<Trend> trends;
  final int workoutsThisWeek;
  final int workoutsLastWeek;
  final double trimpThisWeek;
  final double trimpLastWeek;

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    HealthMetric? metric(Object? raw) =>
        raw is String ? MetricsApi.metricFromBackend(raw) : null;
    return WeeklyReport(
      trends: [
        for (final raw in (json['trends'] as List? ?? []))
          if (metric((raw as Map)['metric']) != null)
            Trend(
              metric: metric(raw['metric'])!,
              thisWeekAvg: (raw['thisWeekAvg'] as num).toDouble(),
              lastWeekAvg: (raw['lastWeekAvg'] as num).toDouble(),
              changePct: (raw['changePct'] as num).toDouble(),
              direction: raw['direction'] as String,
            ),
      ],
      workoutsThisWeek: (json['workoutsThisWeek'] as num?)?.toInt() ?? 0,
      workoutsLastWeek: (json['workoutsLastWeek'] as num?)?.toInt() ?? 0,
      trimpThisWeek: (json['trimpThisWeek'] as num?)?.toDouble() ?? 0,
      trimpLastWeek: (json['trimpLastWeek'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Инсайты, рассчитанные бэкендом из истории пользователя.
class Insights {
  const Insights({
    this.healthScore,
    this.sleepScore,
    this.readinessScore,
    this.scores = const [],
    this.trainingLoad,
    this.night,
    this.vo2Max,
    this.stressTimeline = const [],
    this.baselines = const [],
    this.trends = const [],
    this.anomalies = const [],
  });

  final int? healthScore;
  final int? sleepScore;
  final int? readinessScore;

  /// Все скоры (recovery, sleep, strain, stress, ...) с факторами.
  final List<Score> scores;
  final TrainingLoad? trainingLoad;
  final NightVitals? night;

  /// Оценка VO₂max по Уту—Соренсену (15.3 × HRmax / пульс покоя).
  final double? vo2Max;
  final List<StressPoint> stressTimeline;
  final List<Baseline> baselines;
  final List<Trend> trends;
  final List<Anomaly> anomalies;

  Score? score(String key) {
    for (final s in scores) {
      if (s.key == key) return s;
    }
    return null;
  }

  factory Insights.fromJson(Map<String, dynamic> json) {
    HealthMetric? metric(Object? raw) =>
        raw is String ? MetricsApi.metricFromBackend(raw) : null;

    final loadRaw = json['trainingLoad'] as Map?;
    return Insights(
      healthScore: json['healthScore'] as int?,
      sleepScore: json['sleepScore'] as int?,
      readinessScore: json['readinessScore'] as int?,
      scores: [
        for (final raw in (json['scores'] as List? ?? []))
          Score(
            key: (raw as Map)['key'] as String,
            title: raw['title'] as String,
            value: raw['value'] as int,
            factors: [
              for (final f in (raw['factors'] as List? ?? []))
                ScoreFactor(
                  name: (f as Map)['name'] as String,
                  detail: f['detail'] as String,
                  impact: f['impact'] as String,
                ),
            ],
          ),
      ],
      trainingLoad: loadRaw == null
          ? null
          : TrainingLoad(
              acuteLoad: (loadRaw['acuteLoad'] as num).toDouble(),
              chronicLoad: (loadRaw['chronicLoad'] as num).toDouble(),
              ratio: (loadRaw['ratio'] as num?)?.toDouble(),
              status: loadRaw['status'] as String,
            ),
      night: json['night'] is Map
          ? NightVitals.fromJson(Map<String, dynamic>.from(json['night'] as Map))
          : null,
      vo2Max: (json['vo2Max'] as num?)?.toDouble(),
      stressTimeline: [
        for (final raw in (json['stressTimeline'] as List? ?? []))
          StressPoint(
            at: DateTime.parse((raw as Map)['at'] as String).toLocal(),
            value: (raw['value'] as num).toInt(),
          ),
      ],
      baselines: [
        for (final raw in (json['baselines'] as List? ?? []))
          if (metric((raw as Map)['metric']) != null)
            Baseline(
              metric: metric(raw['metric'])!,
              avg: (raw['avg'] as num).toDouble(),
              stdDev: (raw['stdDev'] as num).toDouble(),
              current: (raw['current'] as num?)?.toDouble(),
              deviationPct: (raw['deviationPct'] as num?)?.toDouble(),
            ),
      ],
      trends: [
        for (final raw in (json['trends'] as List? ?? []))
          if (metric((raw as Map)['metric']) != null)
            Trend(
              metric: metric(raw['metric'])!,
              thisWeekAvg: (raw['thisWeekAvg'] as num).toDouble(),
              lastWeekAvg: (raw['lastWeekAvg'] as num).toDouble(),
              changePct: (raw['changePct'] as num).toDouble(),
              direction: raw['direction'] as String,
            ),
      ],
      anomalies: [
        for (final raw in (json['anomalies'] as List? ?? []))
          if (metric((raw as Map)['metric']) != null)
            Anomaly(
              metric: metric(raw['metric'])!,
              message: raw['message'] as String,
              severity: raw['severity'] as String,
            ),
      ],
    );
  }
}
