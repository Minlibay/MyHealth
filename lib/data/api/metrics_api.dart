import 'package:dio/dio.dart';

import '../../core/health_metric.dart';
import '../../core/health_status.dart';
import '../../core/metric_format.dart';
import '../auth/auth_session.dart';
import '../metric_reading.dart';
import '../metric_sample.dart';
import 'api_client.dart';

/// Вызовы синхронизации показателей (/api/metrics): выгрузка и чтение.
class MetricsApi {
  MetricsApi(this._client);
  final ApiClient _client;

  /// heartRate -> HeartRate (формат enum бэкенда).
  static String backendMetric(HealthMetric m) =>
      m.name[0].toUpperCase() + m.name.substring(1);

  /// HeartRate -> heartRate -> HealthMetric (или null, если неизвестен).
  static HealthMetric? metricFromBackend(String name) {
    final dart = name[0].toLowerCase() + name.substring(1);
    for (final m in HealthMetric.values) {
      if (m.name == dart) return m;
    }
    return null;
  }

  /// Выгружает историю одного показателя. Идемпотентно по [MetricSample.time].
  /// Возвращает число вставленных записей.
  Future<int> uploadSamples(HealthMetric metric, List<MetricSample> samples) async {
    if (samples.isEmpty) return 0;
    final items = [
      for (final s in samples)
        {
          'metric': backendMetric(metric),
          'value': s.value,
          if (s.secondary != null) 'secondary': s.secondary,
          'recordedAt': s.time.toUtc().toIso8601String(),
          'clientId': '${metric.name}-${s.time.toUtc().toIso8601String()}',
        }
    ];
    try {
      final res = await _client.dio.post('/api/metrics', data: items);
      if (res.statusCode == 200 && res.data is Map) {
        return (res.data as Map)['inserted'] as int? ?? 0;
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка синхронизации (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }

  /// Последнее значение по каждому показателю (с сервера).
  Future<Map<HealthMetric, MetricReading?>> fetchLatest() async {
    final list = await _get('/api/metrics/latest');
    final result = <HealthMetric, MetricReading?>{
      for (final m in HealthMetric.values) m: null
    };
    for (final raw in list) {
      final map = Map<String, dynamic>.from(raw as Map);
      final metric = metricFromBackend(map['metric'] as String);
      if (metric == null) continue;
      final value = (map['value'] as num).toDouble();
      final secondary = (map['secondary'] as num?)?.toDouble();
      result[metric] = MetricReading(
        metric: metric,
        // displayValue и status рассчитаны на сервере.
        displayValue: (map['displayValue'] as String?) ??
            formatMetricDisplay(metric, value, secondary),
        value: value,
        secondary: secondary,
        time: DateTime.parse(map['recordedAt'] as String),
        source: map['source'] as String?,
        status: HealthStatus.fromApi(map['status'] as String?),
      );
    }
    return result;
  }

  /// История показателя за период (по возрастанию времени).
  Future<List<MetricSample>> fetchSeries(HealthMetric metric, {int days = 7}) async {
    final from = DateTime.now().toUtc().subtract(Duration(days: days));
    final list = await _get('/api/metrics', query: {
      'metric': backendMetric(metric),
      'from': from.toIso8601String(),
      'limit': 5000,
    });
    final samples = [
      for (final raw in list)
        MetricSample(
          time: DateTime.parse((raw as Map)['recordedAt'] as String),
          value: ((raw)['value'] as num).toDouble(),
          secondary: ((raw)['secondary'] as num?)?.toDouble(),
        )
    ];
    samples.sort((a, b) => a.time.compareTo(b.time));
    return samples;
  }

  Future<List<dynamic>> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _client.dio.get(path, queryParameters: query);
      if (res.statusCode == 200 && res.data is List) {
        return res.data as List<dynamic>;
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка запроса (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }
}
