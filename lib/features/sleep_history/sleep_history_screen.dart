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

/// Ночи за месяц: гипнограммы рядом + средние доли фаз.
class SleepHistoryScreen extends ConsumerWidget {
  const SleepHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(sleepSessionsProvider(30)).value;
    final ring = ref.watch(ringSyncProvider).history?.sleepSessions;
    final sessions = (cloud != null && cloud.isNotEmpty)
        ? cloud
        : (ring ?? const <SleepSessionModel>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('Ночи')),
      body: sessions.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Пока нет ночей с фазами. Синхронизируйте кольцо — '
                  'сессии сна появятся здесь.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _MonthlyAverages(sessions: sessions),
                const SizedBox(height: 16),
                for (final s in sessions) _NightRow(session: s),
              ],
            ),
    );
  }
}

/// Средние доли фаз за период.
class _MonthlyAverages extends StatelessWidget {
  const _MonthlyAverages({required this.sessions});

  final List<SleepSessionModel> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = <SleepStageType, Duration>{};
    var overall = Duration.zero;
    for (final s in sessions) {
      for (final stage in SleepStageType.values) {
        final d = s.hoursOf(stage);
        totals[stage] = (totals[stage] ?? Duration.zero) + d;
        overall += d;
      }
    }
    if (overall == Duration.zero) return const SizedBox.shrink();

    final avgAsleep = sessions
            .map((s) => s.asleep.inMinutes)
            .fold(0, (a, b) => a + b) /
        sessions.length /
        60;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Среднее за ${sessions.length} ноч. · '
                '${avgAsleep.toStringAsFixed(1)} ч сна',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final stage in SleepStageType.values)
                  if ((totals[stage] ?? Duration.zero) > Duration.zero)
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
                          '${stage.label} '
                          '${(totals[stage]!.inMinutes / overall.inMinutes * 100).round()}%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NightRow extends StatelessWidget {
  const _NightRow({required this.session});

  final SleepSessionModel session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = session.asleep.inMinutes / 60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('EE, d MMM', 'ru').format(session.end),
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                '${DateFormat.Hm().format(session.start)}–'
                '${DateFormat.Hm().format(session.end)} · '
                '${hours.toStringAsFixed(1)} ч',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 16,
              child: session.stages.isEmpty
                  ? Container(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4))
                  : Row(
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
        ],
      ),
    );
  }
}
