import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health_metric.dart';
import '../../core/metric_format.dart';
import '../auth/auth_controller.dart';
import '../metric_reading.dart';
import '../metric_sample.dart';
import 'ring_models.dart';
import 'ring_providers.dart';

// cloudModeProvider живёт в providers.dart; импортируем через barrel ниже.
import '../../providers.dart' show cloudModeProvider;

const _ringSource = 'Кольцо JCRing X3';

/// Захватывает живые данные кольца: держит последние значения как
/// [MetricReading] (для дашборда) и периодически выгружает их на сервер.
class RingCaptureController
    extends Notifier<Map<HealthMetric, MetricReading?>> {
  DateTime? _lastUpload;

  @override
  Map<HealthMetric, MetricReading?> build() {
    ref.listen(ringLiveDataProvider, (_, next) {
      final data = next.value;
      if (data == null) return;
      state = _toReadings(data);
      _maybeUpload();
    });
    return const {};
  }

  Map<HealthMetric, MetricReading?> _toReadings(RingLiveData d) {
    final map = <HealthMetric, MetricReading?>{};
    void put(HealthMetric metric, num? v) {
      if (v == null) return;
      final value = v.toDouble();
      map[metric] = MetricReading(
        metric: metric,
        value: value,
        displayValue: formatMetricDisplay(metric, value, null),
        time: d.time,
        source: _ringSource,
      );
    }

    put(HealthMetric.heartRate, d.heartRate);
    put(HealthMetric.bloodOxygen, d.spo2);
    put(HealthMetric.steps, d.steps);
    return map;
  }

  /// Выгрузка на сервер не чаще раза в 20 с (кольцо шлёт данные часто).
  void _maybeUpload() {
    if (!ref.read(cloudModeProvider)) return;
    final now = DateTime.now();
    if (_lastUpload != null && now.difference(_lastUpload!).inSeconds < 20) {
      return;
    }
    _lastUpload = now;

    final api = ref.read(metricsApiProvider);
    for (final entry in state.entries) {
      final r = entry.value;
      if (r?.value == null) continue;
      // fire-and-forget; офлайн/ошибки игнорируем.
      api.uploadSamples(entry.key, [
        MetricSample(time: r!.time, value: r.value!, secondary: r.secondary),
      ]).catchError((_) => 0);
    }
  }
}

final ringCaptureProvider =
    NotifierProvider<RingCaptureController, Map<HealthMetric, MetricReading?>>(
        RingCaptureController.new);
