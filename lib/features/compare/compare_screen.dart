import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/health_metric.dart';
import '../../data/metric_sample.dart';
import '../../providers.dart';

/// Выбранные для сравнения показатели (до шести).
class CompareSelectionController extends Notifier<Set<HealthMetric>> {
  static const maxMetrics = 6;

  @override
  Set<HealthMetric> build() =>
      {HealthMetric.heartRate, HealthMetric.sleep, HealthMetric.steps};

  void toggle(HealthMetric m) {
    final next = {...state};
    if (next.contains(m)) {
      next.remove(m);
    } else if (next.length < maxMetrics) {
      next.add(m);
    }
    state = next;
  }
}

final compareSelectionProvider =
    NotifierProvider<CompareSelectionController, Set<HealthMetric>>(
        CompareSelectionController.new);

/// Сравнение до шести показателей на одном графике.
/// Значения нормируются в 0..1 внутри каждого показателя — сравниваются
/// формы кривых и совпадение пиков, а не абсолютные величины.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = ref.watch(compareSelectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Сравнение метрик')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in HealthMetric.values)
                FilterChip(
                  label: Text(m.title),
                  selected: selected.contains(m),
                  selectedColor: m.color.withValues(alpha: 0.22),
                  checkmarkColor: m.color,
                  onSelected: (_) => ref
                      .read(compareSelectionProvider.notifier)
                      .toggle(m),
                ),
            ],
          ),
          if (selected.length >= CompareSelectionController.maxMetrics)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Максимум ${CompareSelectionController.maxMetrics} метрик одновременно.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
          const SizedBox(height: 16),
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('Неделя')),
                ButtonSegment(value: 30, label: Text('Месяц')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
              child: SizedBox(
                height: 280,
                child: selected.isEmpty
                    ? const Center(child: Text('Выберите показатели'))
                    : _CompareChart(metrics: selected.toList(), days: _days),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Кривые нормированы: 0 — минимум, 1 — максимум показателя за '
            'период. Так видно совпадение пиков и провалов разных метрик.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _CompareChart extends ConsumerWidget {
  const _CompareChart({required this.metrics, required this.days});

  final List<HealthMetric> metrics;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));

    final lines = <LineChartBarData>[];
    final legend = <Widget>[];
    var loading = false;

    for (final metric in metrics) {
      final series =
          ref.watch(metricSeriesProvider((metric: metric, days: days)));
      if (series.isLoading) loading = true;
      final samples = series.value ?? const <MetricSample>[];
      if (samples.length < 2) continue;

      final values = samples.map((s) => s.value).toList();
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);
      final range = (max - min).abs() < 1e-9 ? 1.0 : max - min;

      lines.add(LineChartBarData(
        spots: [
          for (final s in samples)
            FlSpot(
              s.time.difference(from).inMinutes / (days * 24 * 60),
              (s.value - min) / range,
            ),
        ],
        color: metric.color,
        barWidth: 2,
        isCurved: true,
        preventCurveOverShooting: true,
        dotData: const FlDotData(show: false),
      ));
      legend.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: metric.color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 5),
          Text(metric.title, style: theme.textTheme.bodySmall),
        ],
      ));
    }

    if (lines.isEmpty) {
      return Center(
          child: loading
              ? const CircularProgressIndicator()
              : const Text('Недостаточно данных за период'));
    }

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 1,
              minY: -0.05,
              maxY: 1.05,
              lineBarsData: lines,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 0.5,
                    getTitlesWidget: (v, meta) {
                      final date =
                          from.add(Duration(minutes: (v * days * 24 * 60).round()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(DateFormat('d MMM', 'ru').format(date),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: legend),
      ],
    );
  }
}
