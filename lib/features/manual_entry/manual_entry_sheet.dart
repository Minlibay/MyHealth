import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health_metric.dart';
import '../../core/metric_source.dart';
import '../../data/auth/auth_controller.dart';
import '../../data/metric_sample.dart';
import '../../providers.dart';

/// Показатели, которые имеет смысл вводить руками (тонометр, весы,
/// глюкометр, термометр и т.п. без синхронизации).
const _manualMetrics = [
  HealthMetric.weight,
  HealthMetric.bloodPressure,
  HealthMetric.bloodGlucose,
  HealthMetric.bodyTemperature,
  HealthMetric.water,
  HealthMetric.dietaryEnergy,
  HealthMetric.height,
];

/// Открывает форму ручного ввода измерения.
Future<void> showManualEntrySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ManualEntrySheet(),
  );
}

class _ManualEntrySheet extends ConsumerStatefulWidget {
  const _ManualEntrySheet();

  @override
  ConsumerState<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<_ManualEntrySheet> {
  HealthMetric _metric = HealthMetric.weight;
  final _valueCtrl = TextEditingController();
  final _secondaryCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _valueCtrl.dispose();
    _secondaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_valueCtrl.text.replaceAll(',', '.'));
    final secondary =
        double.tryParse(_secondaryCtrl.text.replaceAll(',', '.'));
    final needsSecondary = _metric == HealthMetric.bloodPressure;
    if (value == null || (needsSecondary && secondary == null)) {
      setState(() => _error = 'Введите корректное значение.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final sample = MetricSample(
        time: DateTime.now(),
        value: value,
        secondary: needsSecondary ? secondary : null,
        source: MetricSource.manual,
      );
      await ref.read(metricsApiProvider).uploadSamples(_metric, [sample]);
      ref.invalidate(readingsProvider);
      ref.invalidate(metricSeriesProvider);
      ref.invalidate(insightsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cloudMode = ref.watch(cloudModeProvider);
    final isBp = _metric == HealthMetric.bloodPressure;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Добавить измерение', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            cloudMode
                ? 'Запись сохранится в облаке с пометкой «Ручной ввод».'
                : 'Войдите в аккаунт, чтобы сохранять ручные измерения.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _manualMetrics)
                ChoiceChip(
                  label: Text(m.title),
                  selected: _metric == m,
                  onSelected: (_) => setState(() => _metric = m),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valueCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isBp ? 'Систолическое' : 'Значение',
                    suffixText: isBp ? 'мм рт. ст.' : _metric.unit,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (isBp) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _secondaryCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Диастолическое',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: cloudMode && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}
