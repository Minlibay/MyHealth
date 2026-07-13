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

/// Инсайты, рассчитанные бэкендом из истории пользователя.
class Insights {
  const Insights({
    this.healthScore,
    this.sleepScore,
    this.readinessScore,
    this.scores = const [],
    this.trainingLoad,
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
