import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import 'api_client.dart';

class TagEntry {
  const TagEntry({required this.id, required this.tag, required this.at});
  final String id;
  final String tag;
  final DateTime at;
}

/// Журнал тегов (/api/tags): быстрые отметки образа жизни.
class TagsApi {
  TagsApi(this._client);
  final ApiClient _client;

  Future<void> add(String tag, {DateTime? at}) async {
    try {
      final res = await _client.dio.post('/api/tags', data: {
        'tag': tag,
        if (at != null) 'at': at.toUtc().toIso8601String(),
      });
      if (res.statusCode == 200) return;
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка сохранения тега (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }

  Future<List<TagEntry>> fetch({int days = 7}) async {
    final from = DateTime.now().toUtc().subtract(Duration(days: days));
    try {
      final res = await _client.dio.get('/api/tags', queryParameters: {
        'from': from.toIso8601String(),
      });
      if (res.statusCode == 200 && res.data is List) {
        return [
          for (final raw in res.data as List)
            TagEntry(
              id: (raw as Map)['id'] as String,
              tag: raw['tag'] as String,
              at: DateTime.parse(raw['at'] as String).toLocal(),
            ),
        ];
      }
      if (res.statusCode == 401) {
        throw const ApiException('Сессия истекла, войдите снова.');
      }
      throw ApiException('Ошибка запроса тегов (${res.statusCode}).');
    } on DioException catch (e) {
      throw ApiException('Нет связи с сервером: ${e.message ?? e.type.name}');
    }
  }
}
