import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health_metric.dart';
import '../../core/metric_format.dart';
import '../../data/metric_reading.dart';
import '../../data/profile_controller.dart';
import '../../providers.dart';

/// Сводка активности за сегодня: движение, энергия, минуты — в одном месте,
/// с прогрессом к целям где они заданы.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  /// Метрики активности (кумулятивные за день).
  static const _metrics = [
    HealthMetric.steps,
    HealthMetric.activeEnergy,
    HealthMetric.exerciseTime,
    HealthMetric.moveMinutes,
    HealthMetric.standTime,
    HealthMetric.distance,
    HealthMetric.flightsClimbed,
    HealthMetric.totalCalories,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings = ref.watch(readingsProvider);
    final profile = ref.watch(profileControllerProvider).value;

    double? goalFor(HealthMetric m) => switch (m) {
          HealthMetric.steps => (profile?.stepsGoal ?? 8000).toDouble(),
          HealthMetric.exerciseTime => 30,
          HealthMetric.moveMinutes => 30,
          _ => null,
        };

    return Scaffold(
      appBar: AppBar(title: const Text('Активность сегодня')),
      body: readings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Ошибка: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (map) {
          final rows = [
            for (final m in _metrics)
              if (map[m] != null) (m, map[m]!),
          ];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Нет данных активности за сегодня. Разрешите доступ к '
                  'Здоровью и синхронизируйтесь.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(readingsProvider);
              await ref.read(readingsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                for (final (m, r) in rows)
                  _ActivityRow(metric: m, reading: r, goal: goalFor(m)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.metric, required this.reading, this.goal});

  final HealthMetric metric;
  final MetricReading reading;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = reading.value ?? 0;
    final progress = goal != null && goal! > 0 ? (value / goal!).clamp(0.0, 1.0) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(metric.icon, color: metric.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(metric.title, style: theme.textTheme.titleSmall)),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.onSurface),
                    children: [
                      TextSpan(
                          text: formatMetricDisplay(metric, value, null)),
                      TextSpan(
                          text: ' ${metric.unit}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  color: metric.color,
                ),
              ),
              const SizedBox(height: 4),
              Text('цель ${goal!.round()} ${metric.unit}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ],
        ),
      ),
    );
  }
}
