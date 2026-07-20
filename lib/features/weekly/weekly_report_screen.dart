import 'package:flutter/material.dart' hide Baseline;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/insights.dart';
import '../../data/auth/auth_controller.dart';
import '../../providers.dart';

/// Недельный отчёт: тренды и тренировки за 7 дней против предыдущих.
final weeklyReportProvider = FutureProvider<WeeklyReport?>((ref) async {
  if (!ref.watch(cloudModeProvider)) return null;
  return ref.watch(insightsApiProvider).fetchWeekly();
});

class WeeklyReportScreen extends ConsumerWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(weeklyReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Итоги недели')),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Ошибка: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Войдите в аккаунт, чтобы видеть итоги недели.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _WorkoutsSummary(report: data),
              const SizedBox(height: 16),
              if (data.trends.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Пока мало данных для сравнения недель. '
                      'Синхронизируйтесь несколько дней.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                _TrendsList(trends: data.trends),
            ],
          );
        },
      ),
    );
  }
}

class _WorkoutsSummary extends StatelessWidget {
  const _WorkoutsSummary({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dTrimp = report.trimpThisWeek - report.trimpLastWeek;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тренировки', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat(context, 'Тренировок',
                    '${report.workoutsThisWeek}',
                    'было ${report.workoutsLastWeek}'),
                _stat(context, 'Нагрузка (TRIMP)',
                    report.trimpThisWeek.round().toString(),
                    '${dTrimp >= 0 ? '+' : ''}${dTrimp.round()} к прошлой'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, String hint) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.headlineSmall),
          Text(hint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _TrendsList extends StatelessWidget {
  const _TrendsList({required this.trends});

  final List<Trend> trends;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Показатели: эта неделя против прошлой',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final t in trends)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(t.metric.icon, size: 18, color: t.metric.color),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(t.metric.title,
                            style: theme.textTheme.bodyMedium)),
                    Text(
                      '${_fmt(t.lastWeekAvg)} → ${_fmt(t.thisWeekAvg)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${t.changePct > 0 ? '+' : ''}${t.changePct.toStringAsFixed(0)}%',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: t.direction == 'flat'
                                ? theme.colorScheme.outline
                                : t.metric.color),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
