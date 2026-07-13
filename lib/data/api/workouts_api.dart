import 'package:dio/dio.dart';

import '../../core/metric_source.dart';
import '../auth/auth_session.dart';
import '../workout.dart';
import 'api_client.dart';

/// Вызовы синхронизации тренировок (/api/workouts): выгрузка и чтение.
class WorkoutsApi {
  WorkoutsApi(this._client);
  final ApiClient _client;

  /// Выгружает тренировки. Идемпотентно по clientId (тип + время начала).
  /// Возвращает число вставленных записей.
  Future<int> uploadWorkouts(List<Workout> workouts) async {
    if (workouts.isEmpty) return 0;
    final items = [
      for (final w in workouts)
        {
          'activityType': w.activityType,
          'startedAt': w.start.toUtc().toIso8601String(),
          'endedAt': w.end.toUtc().toIso8601String(),
          if (w.energyKcal != null) 'energyKcal': w.energyKcal,
          if (w.distanceMeters != null) 'distanceMeters': w.distanceMeters,
          if (w.source != null) 'source': w.source!.toApi(),
          'clientId':
              'workout-${w.activityType}-${w.start.toUtc().toIso8601String()}',
        }
    ];
    try {
      final res = await _client.dio.post('/api/workouts', data: items);
      if (res.statusCode == 200 && res.data is Map) {
        return (res.data as Map)['inserted'] as int? ?? 0;
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка синхронизации тренировок (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }

  /// Тренировки за период (новые первыми).
  Future<List<Workout>> fetchWorkouts({int days = 30}) async {
    final from = DateTime.now().toUtc().subtract(Duration(days: days));
    try {
      final res = await _client.dio.get('/api/workouts', queryParameters: {
        'from': from.toIso8601String(),
        'limit': 500,
      });
      if (res.statusCode == 200 && res.data is List) {
        return [
          for (final raw in res.data as List)
            Workout(
              activityType: (raw as Map)['activityType'] as String,
              start: DateTime.parse(raw['startedAt'] as String),
              end: DateTime.parse(raw['endedAt'] as String),
              energyKcal: (raw['energyKcal'] as num?)?.toDouble(),
              distanceMeters: (raw['distanceMeters'] as num?)?.toDouble(),
              source: MetricSource.fromApi(raw['source'] as String?),
              avgHr: (raw['avgHr'] as num?)?.toDouble(),
              maxHr: (raw['maxHr'] as num?)?.toDouble(),
              zonesMinutes: (raw['zonesMinutes'] as List?)
                  ?.map((z) => (z as num).toDouble())
                  .toList(),
              trimp: (raw['trimp'] as num?)?.toDouble(),
            ),
        ];
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка запроса тренировок (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }
}
