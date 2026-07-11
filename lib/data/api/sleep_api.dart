import 'package:dio/dio.dart';

import '../../core/metric_source.dart';
import '../auth/auth_session.dart';
import '../sleep_session.dart';
import 'api_client.dart';

/// Вызовы сессий сна с фазами (/api/sleep).
class SleepApi {
  SleepApi(this._client);
  final ApiClient _client;

  /// Выгружает сессии сна. Идемпотентно по clientId (время начала).
  Future<int> uploadSessions(List<SleepSessionModel> sessions) async {
    if (sessions.isEmpty) return 0;
    final items = [
      for (final s in sessions)
        {
          'startedAt': s.start.toUtc().toIso8601String(),
          'endedAt': s.end.toUtc().toIso8601String(),
          'stages': [
            for (final st in s.stages)
              {
                'stage': st.stage.apiKey,
                'start': st.start.toUtc().toIso8601String(),
                'end': st.end.toUtc().toIso8601String(),
              }
          ],
          if (s.source != null) 'source': s.source!.toApi(),
          'clientId': 'sleep-${s.start.toUtc().toIso8601String()}',
        }
    ];
    try {
      final res = await _client.dio.post('/api/sleep', data: items);
      if (res.statusCode == 200 && res.data is Map) {
        return (res.data as Map)['inserted'] as int? ?? 0;
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка синхронизации сна (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }

  /// Сессии сна за период (новые первыми).
  Future<List<SleepSessionModel>> fetchSessions({int days = 30}) async {
    final from = DateTime.now().toUtc().subtract(Duration(days: days));
    try {
      final res = await _client.dio.get('/api/sleep', queryParameters: {
        'from': from.toIso8601String(),
        'limit': 366,
      });
      if (res.statusCode == 200 && res.data is List) {
        return [
          for (final raw in res.data as List)
            SleepSessionModel(
              start: DateTime.parse((raw as Map)['startedAt'] as String),
              end: DateTime.parse(raw['endedAt'] as String),
              source: MetricSource.fromApi(raw['source'] as String?),
              stages: [
                for (final st in (raw['stages'] as List? ?? []))
                  if (SleepStageType.fromApi((st as Map)['stage'] as String?) !=
                      null)
                    SleepStage(
                      stage: SleepStageType.fromApi(st['stage'] as String?)!,
                      start: DateTime.parse(st['start'] as String),
                      end: DateTime.parse(st['end'] as String),
                    ),
              ],
            ),
        ];
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка запроса сна (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }
}
