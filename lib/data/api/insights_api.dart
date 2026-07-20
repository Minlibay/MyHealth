import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import '../insights.dart';
import 'api_client.dart';

/// Клиент инсайтов (/api/insights): скоры, базовые линии, тренды, аномалии.
class InsightsApi {
  InsightsApi(this._client);
  final ApiClient _client;

  Future<Insights> fetch() async {
    try {
      final res = await _client.dio.get('/api/insights');
      if (res.statusCode == 200 && res.data is Map) {
        return Insights.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка запроса инсайтов (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }

  Future<WeeklyReport> fetchWeekly() async {
    try {
      final res = await _client.dio.get('/api/insights/weekly');
      if (res.statusCode == 200 && res.data is Map) {
        return WeeklyReport.fromJson(
            Map<String, dynamic>.from(res.data as Map));
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка запроса отчёта (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }
}
