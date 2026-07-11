import 'package:dio/dio.dart';

import '../../core/api_config.dart';

/// Тонкая обёртка над Dio: единый базовый URL, подстановка JWT и
/// прозрачное обновление пары токенов по 401 (single-flight, с повтором
/// исходного запроса).
class ApiClient {
  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      // Не бросать исключение на 4xx — обрабатываем коды сами.
      validateStatus: (s) => s != null && s < 500,
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        final path = response.requestOptions.path;
        final isAuthCall = path.startsWith('/api/auth/');
        if (response.statusCode != 401 ||
            isAuthCall ||
            refreshToken == null ||
            refreshToken!.isEmpty) {
          return handler.next(response);
        }
        // Access-токен истёк — обновляем пару и повторяем исходный запрос.
        final ok = await _refreshTokens();
        if (!ok) return handler.next(response);
        final opts = response.requestOptions;
        opts.headers['Authorization'] = 'Bearer $token';
        try {
          handler.resolve(await dio.fetch(opts));
        } on DioException {
          handler.next(response);
        }
      },
    ));
  }

  late final Dio dio;

  /// JWT текущей сессии. Устанавливается контроллером аутентификации.
  String? token;

  /// Refresh-токен. Ротируется сервером при каждом обновлении.
  String? refreshToken;

  /// Вызывается после успешной ротации — контроллер сохраняет новую пару.
  void Function(String token, String refreshToken)? onTokensRefreshed;

  /// Вызывается, когда refresh не удался — сессию нужно завершить.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  Future<bool> _refreshTokens() {
    // Параллельные 401 ждут один и тот же refresh-запрос.
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    try {
      final res = await dio.post('/api/auth/refresh',
          data: {'refreshToken': refreshToken});
      if (res.statusCode == 200 && res.data is Map) {
        final map = res.data as Map;
        token = map['token'] as String;
        refreshToken = map['refreshToken'] as String;
        onTokensRefreshed?.call(token!, refreshToken!);
        return true;
      }
    } on DioException {
      // Сеть недоступна — не считаем сессию протухшей, просто вернём 401.
      return false;
    }
    // Сервер отверг refresh-токен — сессия завершена.
    token = null;
    refreshToken = null;
    onSessionExpired?.call();
    return false;
  }
}
