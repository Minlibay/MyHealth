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

/// Инсайты, рассчитанные бэкендом из истории пользователя.
class Insights {
  const Insights({
    this.healthScore,
    this.sleepScore,
    this.readinessScore,
    this.baselines = const [],
    this.trends = const [],
    this.anomalies = const [],
  });

  final int? healthScore;
  final int? sleepScore;
  final int? readinessScore;
  final List<Baseline> baselines;
  final List<Trend> trends;
  final List<Anomaly> anomalies;

  factory Insights.fromJson(Map<String, dynamic> json) {
    HealthMetric? metric(Object? raw) =>
        raw is String ? MetricsApi.metricFromBackend(raw) : null;

    return Insights(
      healthScore: json['healthScore'] as int?,
      sleepScore: json['sleepScore'] as int?,
      readinessScore: json['readinessScore'] as int?,
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
