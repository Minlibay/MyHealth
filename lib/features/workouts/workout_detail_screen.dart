import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/workout.dart';

const _zoneColors = [
  Color(0xFF60A5FA), // Z1
  Color(0xFF34D399), // Z2
  Color(0xFFFBBF24), // Z3
  Color(0xFFFB923C), // Z4
  Color(0xFFF87171), // Z5
];

const _zoneNames = [
  'Z1 · Разминка',
  'Z2 · Жиросжигание',
  'Z3 · Аэробная',
  'Z4 · Анаэробная',
  'Z5 · Максимум',
];

/// Детальный экран одной тренировки: длительность, калории, дистанция,
/// пульс (средний/макс), зоны пульса с минутами и TRIMP.
class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = workout;
    final minutes = w.duration.inMinutes;
    final dur = minutes >= 60
        ? '${minutes ~/ 60} ч ${minutes % 60} мин'
        : '$minutes мин';

    return Scaffold(
      appBar: AppBar(title: Text(w.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            '${DateFormat('EEEE, d MMMM · HH:mm', 'ru').format(w.start)}–'
            '${DateFormat.Hm().format(w.end)}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          // Ключевые метрики плиткой.
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat(context, 'Длительность', dur, Icons.timer_outlined),
              if (w.energyKcal != null)
                _stat(context, 'Калории', '${w.energyKcal!.round()} ккал',
                    Icons.local_fire_department_rounded),
              if (w.distanceMeters != null)
                _stat(
                    context,
                    'Дистанция',
                    '${(w.distanceMeters! / 1000).toStringAsFixed(2)} км',
                    Icons.route_rounded),
              if (w.avgHr != null)
                _stat(context, 'Средний пульс', '${w.avgHr!.round()} уд/мин',
                    Icons.favorite_rounded),
              if (w.maxHr != null)
                _stat(context, 'Макс. пульс', '${w.maxHr!.round()} уд/мин',
                    Icons.favorite_border_rounded),
              if (w.trimp != null)
                _stat(context, 'Нагрузка', 'TRIMP ${w.trimp!.round()}',
                    Icons.fitness_center_rounded),
              if (w.distanceMeters != null && minutes > 0)
                _stat(
                    context,
                    'Темп',
                    _pace(w.distanceMeters!, minutes),
                    Icons.speed_rounded),
            ],
          ),
          if (w.zonesMinutes != null && w.zonesMinutes!.any((z) => z > 0)) ...[
            const SizedBox(height: 24),
            Text('Зоны пульса', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _ZonesDetail(zones: w.zonesMinutes!),
          ],
          const SizedBox(height: 20),
          Text(
            'Источник: ${w.source?.label ?? '—'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  /// Темп мин/км для беговых/ходьбовых; для остальных — км/ч.
  String _pace(double meters, int minutes) {
    final km = meters / 1000;
    if (km < 0.1) return '—';
    final t = workout.activityType.toUpperCase();
    final isFoot = t.contains('RUN') || t.contains('WALK') || t.contains('HIK');
    if (isFoot) {
      final paceMin = minutes / km;
      final m = paceMin.floor();
      final s = ((paceMin - m) * 60).round();
      return "$m'${s.toString().padLeft(2, '0')}\"/км";
    }
    return '${(km / (minutes / 60)).toStringAsFixed(1)} км/ч';
  }

  Widget _stat(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZonesDetail extends StatelessWidget {
  const _ZonesDetail({required this.zones});

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
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (var i = 0; i < zones.length && i < 5; i++)
                  if (zones[i] > 0)
                    Expanded(
                      flex: (zones[i] / total * 1000).round().clamp(1, 100000),
                      child: Container(color: _zoneColors[i]),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < zones.length && i < 5; i++)
          if (zones[i] > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _zoneColors[i],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_zoneNames[i],
                      style: theme.textTheme.bodyMedium)),
                  Text('${zones[i].round()} мин',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
      ],
    );
  }
}
