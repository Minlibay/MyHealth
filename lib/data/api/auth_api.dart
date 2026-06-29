import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import 'api_client.dart';

/// Вызовы аутентификации (/api/auth).
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  Future<AuthSession> register(String email, String password,
      {String? displayName}) async {
    final res = await _post('/api/auth/register', {
      'email': email,
      'password': password,
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
    });
    return AuthSession.fromJson(res);
  }

  Future<AuthSession> login(String email, String password) async {
    final res = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(res);
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    try {
      final r = await _client.dio.post(path, data: body);
      if (r.statusCode == 200 && r.data is Map) {
        return Map<String, dynamic>.from(r.data as Map);
      }
      if (r.statusCode == 401) {
        throw const ApiException('Неверный email или пароль.');
      }
      final msg = (r.data is Map && (r.data as Map)['error'] != null)
          ? (r.data as Map)['error'].toString()
          : 'Ошибка ${r.statusCode}.';
      throw ApiException(msg);
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }
}
