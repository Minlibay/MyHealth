import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/ring/ring_sync.dart';
import '../../data/sleep_session.dart';
import '../../providers.dart';

Color _stageColor(SleepStageType stage) => switch (stage) {
      SleepStageType.deep => const Color(0xFF3730A3),
      SleepStageType.light => const Color(0xFF818CF8),
      SleepStageType.rem => const Color(0xFF22D3EE),
      SleepStageType.awake => const Color(0xFFF59E0B),
    };

/// Последняя сессия сна с фазами: из облака, либо из последней
/// синхронизации кольца (локальный режим).
final _latestSleepSessionProvider = Provider<SleepSessionModel?>((ref) {
  final cloud = ref.watch(sleepSessionsProvider(7)).value;
  if (cloud != null && cloud.isNotEmpty) return cloud.first;
  final ring = ref.watch(ringSyncProvider).history?.sleepSessions;
  if (ring != null && ring.isNotEmpty) return ring.first;
  return null;
});

/// Гипнограмма последней ночи: полоса фаз по времени + итоги по фазам.
class HypnogramCard extends ConsumerWidget {
  const HypnogramCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(_latestSleepSessionProvider);
    if (session == null || session.stages.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    String hm(Duration d) =>
        d.inHours > 0 ? '${d.inHours} ч ${d.inMinutes % 60} мин' : '${d.inMinutes} мин';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Фазы сна', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${DateFormat.Hm().format(session.start)} – '
                  '${DateFormat.Hm().format(session.end)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Полоса фаз: ширина сегмента пропорциональна длительности.
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 26,
                child: Row(
                  children: [
                    for (final st in session.stages)
                      Expanded(
                        flex: st.duration.inMinutes.clamp(1, 100000),
                        child: Container(color: _stageColor(st.stage)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final stage in SleepStageType.values)
                  if (session.hoursOf(stage) > Duration.zero)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _stageColor(stage),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${stage.label} ${hm(session.hoursOf(stage))}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
              ],
            ),
            if (session.source != null) ...[
              const SizedBox(height: 8),
              Text('Источник: ${session.source!.label}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ],
        ),
      ),
    );
  }
}
