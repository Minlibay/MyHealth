import 'package:dio/dio.dart';

import '../../core/api_config.dart';

/// Тонкая обёртка над Dio: единый базовый URL и подстановка JWT в заголовок.
class ApiClient {
  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      // Не бросать исключение на 4xx — обрабатываем коды сами.
      validateStatus: (s) => s != null && s < 500,
    ));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }));
  }

  late final Dio dio;

  /// JWT текущей сессии. Устанавливается контроллером аутентификации.
  String? token;
}
