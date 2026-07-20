import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import '../user_profile.dart';
import 'api_client.dart';

/// Профиль пользователя на сервере (/api/user/profile).
class ProfileApi {
  ProfileApi(this._client);
  final ApiClient _client;

  Future<UserProfile> fetch() async {
    try {
      final res = await _client.dio.get('/api/user/profile');
      if (res.statusCode == 200 && res.data is Map) {
        return UserProfile.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка запроса профиля (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }

  Future<void> save(UserProfile profile) async {
    try {
      final res =
          await _client.dio.put('/api/user/profile', data: profile.toJson());
      if (res.statusCode == 200) return;
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка сохранения профиля (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }
}
