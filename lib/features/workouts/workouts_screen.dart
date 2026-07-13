import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/workout.dart';
import '../../providers.dart';

/// Список тренировок из активного источника (устройство или облако).
class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final workouts = ref.watch(workoutsProvider(_days));

    return Scaffold(
      appBar: AppBar(title: const Text('Тренировки')),
      body: Column(
        children: [
          const SizedBox(height: 4),
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('Неделя')),
                ButtonSegment(value: 30, label: Text('Месяц')),
                ButtonSegment(value: 90, label: Text('3 месяца')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: workouts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Ошибка: $e', textAlign: TextAlign.center),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('Тренировок за период нет'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(workoutsProvider);
                        await ref.read(workoutsProvider(_days).future);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _WorkoutTile(workout: list[i])
                                .animate()
                                .fadeIn(delay: (30 * i).ms, duration: 250.ms),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = workout;
    final minutes = w.duration.inMinutes;
    final parts = <String>[
      minutes >= 60 ? '${minutes ~/ 60} ч ${minutes % 60} мин' : '$minutes мин',
      if (w.energyKcal != null) '${w.energyKcal!.round()} ккал',
      if (w.distanceMeters != null)
        '${(w.distanceMeters! / 1000).toStringAsFixed(1)} км',
    ];

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconFor(w.activityType),
                  color: theme.colorScheme.primary, size: 24),
            ),
            title: Text(w.title),
            subtitle: Text(
              [
                DateFormat('d MMM, HH:mm', 'ru').format(w.start),
                if (w.avgHr != null) 'пульс ${w.avgHr!.round()} ср.',
                if (w.trimp != null) 'TRIMP ${w.trimp!.round()}',
                if (w.source != null) w.source!.label,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              parts.join('\n'),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (w.zonesMinutes != null &&
              w.zonesMinutes!.any((z) => z > 0)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _ZonesBar(zones: w.zonesMinutes!),
            ),
          ],
        ],
      ),
    );
  }

  static const _zoneColors = [
    Color(0xFF60A5FA), // Z1 — разминка
    Color(0xFF34D399), // Z2 — жиросжигание
    Color(0xFFFBBF24), // Z3 — аэробная
    Color(0xFFFB923C), // Z4 — анаэробная
    Color(0xFFF87171), // Z5 — максимум
  ];

  IconData _iconFor(String type) {
    final t = type.toUpperCase();
    if (t.contains('RUN')) return Icons.directions_run_rounded;
    if (t.contains('WALK') || t.contains('HIKING')) {
      return Icons.directions_walk_rounded;
    }
    if (t.contains('BIK') || t.contains('CYCL')) {
      return Icons.directions_bike_rounded;
    }
    if (t.contains('SWIM')) return Icons.pool_rounded;
    if (t.contains('YOGA') || t.contains('MEDITATION')) {
      return Icons.self_improvement_rounded;
    }
    if (t.contains('STRENGTH') || t.contains('WEIGHT')) {
      return Icons.fitness_center_rounded;
    }
    if (t.contains('SKI') || t.contains('SNOW')) {
      return Icons.downhill_skiing_rounded;
    }
    if (t.contains('DANC')) return Icons.music_note_rounded;
    if (t.contains('ROW')) return Icons.rowing_rounded;
    if (t.contains('TENNIS') || t.contains('BADMINTON')) {
      return Icons.sports_tennis_rounded;
    }
    if (t.contains('SOCCER') || t.contains('FOOTBALL')) {
      return Icons.sports_soccer_rounded;
    }
    if (t.contains('BASKET')) return Icons.sports_basketball_rounded;
    if (t.contains('BOX') || t.contains('MARTIAL')) {
      return Icons.sports_mma_rounded;
    }
    return Icons.fitness_center_rounded;
  }
}

/// Полоса зон пульса: ширина сегмента пропорциональна минутам в зоне.
class _ZonesBar extends StatelessWidget {
  const _ZonesBar({required this.zones});

  final List<double> zones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = zones.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (var i = 0; i < zones.length && i < 5; i++)
                  if (zones[i] > 0)
                    Expanded(
                      flex: (zones[i] / total * 1000).round().clamp(1, 100000),
                      child: Container(color: _WorkoutTile._zoneColors[i]),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            for (var i = 0; i < zones.length && i < 5; i++)
              if (zones[i] >= 1) 'Z${i + 1} ${zones[i].round()}м',
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11, color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}
