import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health_metric.dart';
import '../../core/health_status.dart';
import '../../core/metric_format.dart';
import '../../core/metric_source.dart';
import '../auth/auth_controller.dart';
import '../metric_reading.dart';
import '../metric_sample.dart';
import 'ring_connection.dart';
import 'ring_models.dart';
import 'ring_providers.dart';

// cloudModeProvider/readingsProvider живут в providers.dart.
import '../../providers.dart' show cloudModeProvider, readingsProvider;

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
    // Атрибуция по конкретному устройству (кольцо/браслет), если известно.
    final deviceName = ref.read(ringDevicesProvider).value?.active?.name;
    final source = deviceName == null
        ? MetricSource.ring
        : MetricSource(MetricSourceType.ring, deviceName);
    final map = <HealthMetric, MetricReading?>{};
    void put(HealthMetric metric, num? v) {
      if (v == null) return;
      final value = v.toDouble();
      map[metric] = MetricReading(
        metric: metric,
        value: value,
        displayValue: formatMetricDisplay(metric, value, null),
        time: d.time,
        source: source,
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
        MetricSample(
            time: r!.time,
            value: r.value!,
            secondary: r.secondary,
            source: r.source),
      ]).catchError((_) => 0);
    }
  }
}

final ringCaptureProvider =
    NotifierProvider<RingCaptureController, Map<HealthMetric, MetricReading?>>(
        RingCaptureController.new);

/// Статусы показателей, рассчитанные на бэкенде, для отображаемых значений
/// (активный источник + живые данные кольца). Единая точка истины по нормам.
final metricStatusesProvider =
    FutureProvider<Map<HealthMetric, HealthStatus>>((ref) async {
  final readings = ref.watch(readingsProvider).value ?? const {};
  final ring = ref.watch(ringCaptureProvider);

  // Кольцо перекрывает базовый источник, только если его данные свежее.
  final merged = <HealthMetric, MetricReading?>{...readings};
  ring.forEach((k, v) {
    merged[k] = preferFresher(merged[k], v);
  });

  // Уже посчитанное сервером (cloud latest) берём как есть.
  final result = <HealthMetric, HealthStatus>{};
  for (final e in merged.entries) {
    if (e.value != null && e.value!.status.isMeaningful) {
      result[e.key] = e.value!.status;
    }
  }
  // Остальное считаем через бэкенд (анонимный /evaluate).
  final evaluated = await ref.watch(evaluationApiProvider).evaluate(merged);
  evaluated.forEach((k, v) => result.putIfAbsent(k, () => v));
  return result;
});
