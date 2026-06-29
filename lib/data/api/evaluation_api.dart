import 'package:dio/dio.dart';

import '../../core/health_metric.dart';
import '../../core/health_status.dart';
import '../metric_reading.dart';
import 'api_client.dart';
import 'metrics_api.dart';

/// Клиент к серверному расчёту норм (/api/metrics/evaluate, анонимный).
/// Вся логика — на бэкенде; клиент только отправляет значения и получает статусы.
class EvaluationApi {
  EvaluationApi(this._client);
  final ApiClient _client;

  Future<Map<HealthMetric, HealthStatus>> evaluate(
      Map<HealthMetric, MetricReading?> readings) async {
    final items = [
      for (final e in readings.entries)
        if (e.value?.value != null)
          {
            'metric': MetricsApi.backendMetric(e.key),
            'value': e.value!.value,
            if (e.value!.secondary != null) 'secondary': e.value!.secondary,
          }
    ];
    if (items.isEmpty) return {};

    try {
      final res = await _client.dio.post('/api/metrics/evaluate', data: items);
      if (res.statusCode != 200 || res.data is! List) return {};
      final result = <HealthMetric, HealthStatus>{};
      for (final raw in res.data as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final metric = MetricsApi.metricFromBackend(map['metric'] as String);
        if (metric == null) continue;
        result[metric] = HealthStatus.fromApi(map['status'] as String?);
      }
      return result;
    } on DioException {
      return {};
    }
  }
}
