import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../core/health_metric.dart';
import '../../core/health_status.dart';
import '../../core/metric_format.dart';
import '../../data/metric_reading.dart';
import '../../data/metric_sample.dart';
import '../../data/ring/ring_capture.dart';
import '../../features/dashboard/status_pill.dart';
import '../../providers.dart';
import 'hypnogram_card.dart';
import 'metric_chart.dart';

class MetricDetailScreen extends ConsumerStatefulWidget {
  const MetricDetailScreen({super.key, required this.metric});

  final HealthMetric metric;

  @override
  ConsumerState<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends ConsumerState<MetricDetailScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final metric = widget.metric;
    final series =
        ref.watch(metricSeriesProvider((metric: metric, days: _days)));

    return Scaffold(
      appBar: AppBar(title: Text(metric.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _HeroValue(metric: metric, samples: series.value),
          if (series.value != null && series.value!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Builder(builder: (context) {
              // Статус считает бэкенд (metricStatusesProvider).
              final status = ref.watch(metricStatusesProvider).value?[metric] ??
                  HealthStatus.unknown;
              // Источник — из более свежего чтения (хранилище или кольцо).
              final source = preferFresher(
                ref.watch(readingsProvider).value?[metric],
                ref.watch(ringCaptureProvider)[metric],
              )?.source;
              if (!status.isMeaningful && source == null) {
                return const SizedBox.shrink();
              }
              final theme = Theme.of(context);
              return Row(
                children: [
                  if (status.isMeaningful) ...[
                    StatusPill(status: status),
                    const SizedBox(width: 10),
                  ],
                  if (source != null)
                    Expanded(
                      child: Text(
                        'Источник: ${source.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                ],
              );
            }),
          ],
          // Гипнограмма — только для сна, когда есть сессия с фазами.
          if (metric == HealthMetric.sleep) ...[
            const SizedBox(height: 14),
            const HypnogramCard(),
          ],
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
              child: SizedBox(
                height: 240,
                child: series.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Ошибка: $e')),
                  data: (samples) =>
                      MetricChart(metric: metric, samples: samples),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (series.value != null && series.value!.isNotEmpty) ...[
            _StatsRow(metric: metric, samples: series.value!)
                .animate()
                .fadeIn(duration: 300.ms),
            const SizedBox(height: 20),
            _ValuesList(metric: metric, samples: series.value!),
          ],
        ],
      ),
    );
  }
}

/// Список последних значений: каждое — со временем и источником
/// (кольцо, Apple Health, часы и т.д.), т.к. в серии источники смешаны.
class _ValuesList extends StatefulWidget {
  const _ValuesList({required this.metric, required this.samples});

  final HealthMetric metric;
  final List<MetricSample> samples;

  @override
  State<_ValuesList> createState() => _ValuesListState();
}

class _ValuesListState extends State<_ValuesList> {
  static const _pageSize = 20;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Новые сверху.
    final sorted = [...widget.samples]
      ..sort((a, b) => b.time.compareTo(a.time));
    final visible = sorted.take(_shown).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Значения',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final (i, s) in visible.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  dense: true,
                  title: Text(
                    '${formatMetricDisplay(widget.metric, s.value, s.secondary)}'
                    ' ${widget.metric.unit}',
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Text(
                      DateFormat('d MMM, HH:mm', 'ru').format(s.time)),
                  trailing: s.source == null
                      ? null
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            s.source!.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                ),
              ],
              if (sorted.length > _shown)
                TextButton(
                  onPressed: () =>
                      setState(() => _shown += _ValuesListState._pageSize),
                  child: Text(
                      'Показать ещё (${sorted.length - _shown} записей)'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.metric, required this.samples});

  final HealthMetric metric;
  final List<MetricSample>? samples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = (samples != null && samples!.isNotEmpty) ? samples!.last : null;
    final value = last == null
        ? '—'
        : metric == HealthMetric.bloodPressure && last.secondary != null
            ? '${_fmt(last.value)}/${_fmt(last.secondary!)}'
            : _fmt(last.value);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            metric.color,
            Color.lerp(metric.color, Colors.black, 0.18)!,
          ],
        ),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'metric-icon-${metric.name}',
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(metric.icon, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Последнее значение',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.headlineLarge
                        ?.copyWith(color: Colors.white, fontSize: 34),
                    children: [
                      TextSpan(text: value),
                      TextSpan(
                        text: ' ${metric.unit}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.metric, required this.samples});

  final HealthMetric metric;
  final List<MetricSample> samples;

  @override
  Widget build(BuildContext context) {
    final values = samples.map((s) => s.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        _stat(context, 'Среднее', avg),
        const SizedBox(width: 12),
        _stat(context, 'Минимум', min),
        const SizedBox(width: 12),
        _stat(context, 'Максимум', max),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, double v) {
    final theme = Theme.of(context);
    final text = metric == HealthMetric.steps
        ? v.toStringAsFixed(0)
        : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1));
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 6),
              Text(text,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: metric.color)),
              Text(metric.unit,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
