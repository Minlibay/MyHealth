import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                for (final (i, s) in data.scores.indexed)
                  _ScoreCard(score: s)
                      .animate()
                      .fadeIn(delay: (50 * i).ms, duration: 250.ms),
                if (data.trainingLoad != null &&
                    data.trainingLoad!.status != 'unknown')
                  _TrainingLoadCard(load: data.trainingLoad!),
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
