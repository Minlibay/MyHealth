import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/health_metric.dart';
import '../../core/health_status.dart';
import '../../data/metric_reading.dart';
import '../../data/profile_controller.dart';
import '../../data/ring/ring_capture.dart';
import '../../providers.dart';
import 'sparkline.dart';
import 'status_pill.dart';

class MetricCard extends ConsumerWidget {
  const MetricCard({
    super.key,
    required this.metric,
    required this.reading,
    this.onTap,
  });

  final HealthMetric metric;
  final MetricReading? reading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasData = reading != null;
    final series = ref.watch(metricSeriesProvider((metric: metric, days: 7)));
    final spark = series.value?.map((s) => s.value).toList() ?? const [];
    final statuses = ref.watch(metricStatusesProvider).value ?? const {};
    final status =
        statuses[metric] ?? reading?.status ?? HealthStatus.unknown;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'metric-icon-${metric.name}',
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: metric.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(metric.icon, color: metric.color, size: 22),
                    ),
                  ),
                  const Spacer(),
                  if (hasData)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(reading!.time),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                        if (reading!.source != null)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: Text(
                              reading!.source!.type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(metric.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              if (hasData)
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: theme.colorScheme.onSurface),
                    children: [
                      TextSpan(text: reading!.displayValue),
                      TextSpan(
                        text: ' ${metric.unit}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                )
              else
                Text('—',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: theme.colorScheme.outlineVariant)),
              if (status.isMeaningful) ...[
                const SizedBox(height: 8),
                StatusPill(status: status),
              ],
              // Прогресс к цели (шаги/вода/питание) из профиля.
              if (hasData && _goalFor(ref) != null) ...[
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final goal = _goalFor(ref)!;
                  final progress =
                      ((reading!.value ?? 0) / goal).clamp(0.0, 1.0);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.35),
                          color: metric.color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'цель ${_fmtGoal(goal)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10, color: theme.colorScheme.outline),
                      ),
                    ],
                  );
                }),
              ],
              const Spacer(),
              SizedBox(
                height: 34,
                child: spark.length >= 2
                    ? Sparkline(values: spark, color: metric.color)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Цель для показателя из профиля (с дефолтами для шагов/воды/питания).
  double? _goalFor(WidgetRef ref) {
    final p = ref.watch(profileControllerProvider).value;
    return switch (metric) {
      HealthMetric.steps => (p?.stepsGoal ?? 8000).toDouble(),
      HealthMetric.water => p?.waterGoalLiters ?? 2.0,
      HealthMetric.dietaryEnergy => (p?.kcalGoal ?? 2000).toDouble(),
      _ => null,
    };
  }

  String _fmtGoal(double goal) => goal == goal.roundToDouble()
      ? goal.toInt().toString()
      : goal.toStringAsFixed(1);

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final sameDay =
        now.year == t.year && now.month == t.month && now.day == t.day;
    return sameDay
        ? DateFormat.Hm().format(t)
        : DateFormat('d MMM', 'ru').format(t);
  }
}
