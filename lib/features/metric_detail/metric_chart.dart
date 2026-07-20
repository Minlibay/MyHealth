import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/health_metric.dart';
import '../../data/metric_sample.dart';

/// Линейный график истории показателя. Для давления рисует две линии
/// (систолическое и диастолическое).
class MetricChart extends StatelessWidget {
  const MetricChart({super.key, required this.metric, required this.samples});

  final HealthMetric metric;
  final List<MetricSample> samples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (samples.isEmpty) {
      return const Center(child: Text('Нет данных за период'));
    }

    final primary = [
      for (var i = 0; i < samples.length; i++)
        FlSpot(i.toDouble(), samples[i].value),
    ];
    final hasSecondary = samples.any((s) => s.secondary != null);
    final secondary = hasSecondary
        ? [
            for (var i = 0; i < samples.length; i++)
              FlSpot(i.toDouble(), samples[i].secondary ?? samples[i].value),
          ]
        : null;

    final values = [
      ...samples.map((s) => s.value),
      if (hasSecondary) ...samples.map((s) => s.secondary ?? s.value),
    ];
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.15 + 1;
    // Не уводим ось ниже нуля: у показателей не бывает отрицательных значений.
    minY = (minY - pad).clamp(0, double.infinity).toDouble();
    maxY += pad;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => Text(
                _fmtY(v),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (samples.length / 5).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= samples.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('d.MM').format(samples[i].time),
                      style: theme.textTheme.bodySmall),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          _bar(primary, metric.color),
          if (secondary != null)
            _bar(secondary, Color.lerp(metric.color, Colors.black, 0.35)!),
        ],
      ),
    );
  }

  LineChartBarData _bar(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.12),
        ),
      );

  String _fmtY(double v) {
    if (metric == HealthMetric.steps) {
      return v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
    }
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }
}
