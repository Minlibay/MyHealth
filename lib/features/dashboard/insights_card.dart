import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/insights.dart';
import '../../providers.dart';

/// Карточка инсайтов: Health/Sleep/Readiness Score + аномалии.
/// Показывается только в облачном режиме, когда бэкенду есть что считать.
class InsightsCard extends ConsumerWidget {
  const InsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider).value;
    if (insights == null ||
        (insights.healthScore == null &&
            insights.sleepScore == null &&
            insights.readinessScore == null &&
            insights.anomalies.isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Полный разбор (8 скоров с факторами) — на экране инсайтов.
          onTap: () => context.push('/insights'),
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Сегодня',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Score(label: 'Здоровье', value: insights.healthScore),
                  _Score(label: 'Сон', value: insights.sleepScore),
                  _Score(label: 'Готовность', value: insights.readinessScore),
                ],
              ),
              for (final a in insights.anomalies) ...[
                const SizedBox(height: 10),
                _AnomalyRow(anomaly: a),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.label, required this.value});

  final String label;
  final int? value;

  Color _color(BuildContext context, int v) {
    if (v >= 75) return const Color(0xFF22C55E);
    if (v >= 50) return const Color(0xFFEAB308);
    return Theme.of(context).colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value;
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: CircularProgressIndicator(
                    value: v == null ? 0 : v / 100,
                    strokeWidth: 5,
                    backgroundColor:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    color: v == null
                        ? theme.colorScheme.outlineVariant
                        : _color(context, v),
                  ),
                ),
                Text(v?.toString() ?? '—',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _AnomalyRow extends StatelessWidget {
  const _AnomalyRow({required this.anomaly});

  final Anomaly anomaly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alert = anomaly.severity == 'alert';
    final color = alert ? theme.colorScheme.error : const Color(0xFFEAB308);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(alert ? Icons.error_rounded : Icons.info_rounded,
            size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(anomaly.message, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
