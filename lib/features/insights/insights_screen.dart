import 'package:flutter/material.dart' hide Baseline;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/insights.dart';
import '../../providers.dart';

Color scoreColor(BuildContext context, Score s) {
  final good = s.lowerIsBetter ? 100 - s.value : s.value;
  if (good >= 70) return const Color(0xFF22C55E);
  if (good >= 45) return const Color(0xFFEAB308);
  return Theme.of(context).colorScheme.error;
}

/// Экран инсайтов: восемь скоров с факторами + тренировочная нагрузка.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Инсайты')),
      body: insights.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Ошибка: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (data) {
          if (data == null || data.scores.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Пока мало данных для инсайтов. Синхронизируйте показатели '
                  'несколько дней подряд — появятся персональные оценки.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(insightsProvider);
              await ref.read(insightsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                if (data.night != null && !data.night!.isEmpty)
                  _NightCard(night: data.night!, vo2Max: data.vo2Max),
                if (data.stressTimeline.length >= 3)
                  _StressTimelineCard(points: data.stressTimeline),
                for (final (i, s) in data.scores.indexed)
                  _ScoreCard(score: s)
                      .animate()
                      .fadeIn(delay: (50 * i).ms, duration: 250.ms),
                if (data.trainingLoad != null &&
                    data.trainingLoad!.status != 'unknown')
                  _TrainingLoadCard(load: data.trainingLoad!),
                if (data.trends.isNotEmpty) _TrendsCard(trends: data.trends),
                if (data.baselines.isNotEmpty)
                  _BaselinesCard(baselines: data.baselines),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final Score score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = scoreColor(context, score);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        shape: const Border(),
        leading: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: score.value / 100,
                strokeWidth: 4,
                backgroundColor:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                color: color,
              ),
              Text('${score.value}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        title: Text(score.title),
        subtitle: score.lowerIsBetter
            ? Text('Ниже — лучше',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline))
            : null,
        children: [
          for (final f in score.factors)
            ListTile(
              dense: true,
              leading: Icon(
                switch (f.impact) {
                  'positive' => Icons.arrow_upward_rounded,
                  'negative' => Icons.arrow_downward_rounded,
                  _ => Icons.remove_rounded,
                },
                size: 18,
                color: switch (f.impact) {
                  'positive' => const Color(0xFF22C55E),
                  'negative' => theme.colorScheme.error,
                  _ => theme.colorScheme.outline,
                },
              ),
              title: Text(f.name, style: theme.textTheme.bodyMedium),
              trailing: Text(
                f.detail,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (score.factors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Нет детализации'),
            ),
        ],
      ),
    );
  }
}

/// Ночные показатели: пульс покоя, SpO₂, регулярность + VO₂max.
class _NightCard extends StatelessWidget {
  const _NightCard({required this.night, this.vo2Max});

  final NightVitals night;
  final double? vo2Max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(IconData icon, String label, String value, {String? hint}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (hint != null)
                    Text(hint,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
            Text(value,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.nightlight_round,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Ночь', style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 6),
            if (night.restingHr != null)
              item(
                Icons.favorite_border_rounded,
                'Пульс покоя за ночь',
                '${night.restingHr!.round()} уд/мин',
                hint: night.restingHrBaseline != null
                    ? 'Ваша норма ${night.restingHrBaseline!.round()}'
                    : null,
              ),
            if (night.spo2Min != null)
              item(
                Icons.air_rounded,
                'Минимум SpO₂',
                '${night.spo2Min!.round()}%',
                hint: (night.spo2Dips ?? 0) > 0
                    ? 'Провалов ниже 90%: ${night.spo2Dips}'
                    : 'Без провалов ниже 90%',
              ),
            if (night.sleepRegularityMinutes != null)
              item(
                Icons.schedule_rounded,
                'Регулярность отбоя',
                '±${night.sleepRegularityMinutes!.round()} мин',
                hint: 'Разброс за 14 дней; до 30 минут — отлично',
              ),
            if (vo2Max != null)
              item(
                Icons.directions_run_rounded,
                'VO₂max (оценка)',
                '${vo2Max!.toStringAsFixed(0)} мл/кг/мин',
                hint: 'По пульсу покоя и максимальному пульсу',
              ),
          ],
        ),
      ),
    );
  }
}

/// Почасовой стресс за сутки: мини-столбики.
class _StressTimelineCard extends StatelessWidget {
  const _StressTimelineCard({required this.points});

  final List<StressPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color(int v) => v >= 66
        ? theme.colorScheme.error
        : v >= 33
            ? const Color(0xFFEAB308)
            : const Color(0xFF22C55E);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.monitor_heart_outlined,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Стресс за сутки', style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final p in points) ...[
                    Expanded(
                      child: Container(
                        height: 6 + p.value / 100 * 50,
                        decoration: BoxDecoration(
                          color: color(p.value),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat.Hm().format(points.first.at),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                Text('сейчас',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Тренды: среднее этой недели против прошлой по каждой метрике.
class _TrendsCard extends StatelessWidget {
  const _TrendsCard({required this.trends});

  final List<Trend> trends;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.trending_up_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Тренды за неделю', style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 6),
            for (final t in trends)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(t.metric.icon, size: 18, color: t.metric.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t.metric.title,
                          style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      '${_fmt(t.lastWeekAvg)} → ${_fmt(t.thisWeekAvg)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      switch (t.direction) {
                        'up' => Icons.arrow_upward_rounded,
                        'down' => Icons.arrow_downward_rounded,
                        _ => Icons.remove_rounded,
                      },
                      size: 15,
                      color: t.direction == 'flat'
                          ? theme.colorScheme.outline
                          : t.metric.color,
                    ),
                    SizedBox(
                      width: 44,
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

/// Личные нормы: среднее за 30 дней ± σ и текущее отклонение.
class _BaselinesCard extends StatelessWidget {
  const _BaselinesCard({required this.baselines});

  final List<Baseline> baselines;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.straighten_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Ваши нормы (30 дней)', style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 6),
            for (final b in baselines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(b.metric.icon, size: 18, color: b.metric.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(b.metric.title,
                          style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      '${_fmt(b.avg)} ± ${_fmt(b.stdDev)} ${b.metric.unit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (b.deviationPct != null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${b.deviationPct! > 0 ? '+' : ''}${b.deviationPct!.toStringAsFixed(0)}%',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: b.deviationPct!.abs() < 10
                                ? theme.colorScheme.outline
                                : const Color(0xFFEAB308),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrainingLoadCard extends StatelessWidget {
  const _TrainingLoadCard({required this.load});

  final TrainingLoad load;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (load.status) {
      'optimal' => const Color(0xFF22C55E),
      'high' => const Color(0xFFEAB308),
      'risky' => theme.colorScheme.error,
      _ => theme.colorScheme.outline,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center_rounded,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Тренировочная нагрузка',
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(load.statusLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'За неделю: ${load.acuteLoad.round()} TRIMP · '
              'хроническая: ${load.chronicLoad.round()}'
              '${load.ratio != null ? ' · соотношение ${load.ratio!.toStringAsFixed(2)}' : ''}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              'Соотношение 0.8–1.3 — рост формы без перегрузки; выше 1.5 — '
              'риск травм и выгорания.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
