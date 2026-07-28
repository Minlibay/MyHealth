import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import 'api_client.dart';

class GoogleHealthStatus {
  const GoogleHealthStatus({
    required this.connected,
    this.lastSyncAt,
    this.lastError,
  });

  final bool connected;
  final DateTime? lastSyncAt;
  final String? lastError;
}

/// Подключение Google Health к нашему бэкенду (/api/integrations/google-health).
class GoogleHealthApi {
  GoogleHealthApi(this._client);
  final ApiClient _client;

  /// Отдаёт refresh-токен бэкенду; сервер сразу тянет первые данные.
  /// Возвращает число вставленных записей.
  Future<int> connect(String refreshToken, {String? scopes}) async {
    try {
      final res = await _client.dio.post(
        '/api/integrations/google-health/connect',
        data: {'refreshToken': refreshToken, 'scopes': ?scopes},
      );
      if (res.statusCode == 200 && res.data is Map) {
        return (res.data as Map)['inserted'] as int? ?? 0;
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка подключения (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }

  Future<GoogleHealthStatus> status() async {
    try {
      final res =
          await _client.dio.get('/api/integrations/google-health');
      if (res.statusCode == 200 && res.data is Map) {
        final m = res.data as Map;
        return GoogleHealthStatus(
          connected: m['connected'] as bool? ?? false,
          lastSyncAt: m['lastSyncAt'] != null
              ? DateTime.tryParse(m['lastSyncAt'] as String)?.toLocal()
              : null,
          lastError: m['lastError'] as String?,
        );
      }
      return const GoogleHealthStatus(connected: false);
    } on DioException {
      return const GoogleHealthStatus(connected: false);
    }
  }

  /// Опрос Google (клиент вызывает при обычной синхронизации).
  /// Обход всех типов данных занимает минуты — таймаут увеличен.
  Future<int> sync() async {
    try {
      final res = await _client.dio.post(
        '/api/integrations/google-health/sync',
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 1),
        ),
      );
      if (res.statusCode == 200 && res.data is Map) {
        return (res.data as Map)['inserted'] as int? ?? 0;
      }
      return 0;
    } on DioException {
      return 0;
    }
  }

  Future<void> disconnect() async {
    try {
      await _client.dio.delete('/api/integrations/google-health');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }
}
