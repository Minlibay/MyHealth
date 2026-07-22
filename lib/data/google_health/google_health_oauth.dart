// OAuth-вход в Google Health. На Web недоступен — заглушка.
export 'google_health_oauth_stub.dart'
    if (dart.library.io) 'google_health_oauth_io.dart';

/// Результат входа: refresh-токен и выданные скоупы.
class GoogleHealthAuthResult {
  const GoogleHealthAuthResult({required this.refreshToken, this.scopes});
  final String refreshToken;
  final String? scopes;
}
