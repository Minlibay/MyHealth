import 'dart:convert';

import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import 'api_client.dart';

/// GDPR-вызовы (/api/user): экспорт данных и удаление аккаунта.
class UserApi {
  UserApi(this._client);
  final ApiClient _client;

  /// Полный экспорт данных пользователя как форматированный JSON.
  Future<String> exportData() async {
    try {
      final res = await _client.dio.get('/api/user/export');
      if (res.statusCode == 200) {
        return const JsonEncoder.withIndent('  ').convert(res.data);
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка экспорта (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }

  /// Удаление аккаунта и всех данных. Требует подтверждения паролем.
  Future<void> deleteAccount(String password) async {
    try {
      final res = await _client.dio
          .post('/api/user/delete', data: {'password': password});
      if (res.statusCode == 200) return;
      if (res.statusCode == 400 && res.data is Map) {
        throw ApiException(
            ((res.data as Map)['error'] as String?) ?? 'Неверный пароль.');
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка удаления (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }
}
