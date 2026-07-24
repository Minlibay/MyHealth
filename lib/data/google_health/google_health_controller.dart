import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/google_health_api.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_session.dart';
import 'google_health_oauth.dart';

final googleHealthApiProvider = Provider<GoogleHealthApi>(
    (ref) => GoogleHealthApi(ref.watch(apiClientProvider)));

/// Статус подключения Google Health (с бэкенда).
final googleHealthStatusProvider =
    FutureProvider<GoogleHealthStatus>((ref) async {
  if (ref.watch(authControllerProvider).value == null) {
    return const GoogleHealthStatus(connected: false);
  }
  return ref.watch(googleHealthApiProvider).status();
});

class GoogleHealthController {
  GoogleHealthController(this._ref);
  final Ref _ref;

  /// Полный цикл подключения: OAuth на устройстве → refresh-токен на бэкенд.
  /// Возвращает число загруженных записей; бросает ApiException при ошибке.
  Future<int> connect() async {
    final auth = await signInGoogleHealth();
    if (auth == null) {
      throw const ApiException('Вход отменён или платформа не поддерживается.');
    }
    final inserted = await _ref
        .read(googleHealthApiProvider)
        .connect(auth.refreshToken, scopes: auth.scopes);
    _ref.invalidate(googleHealthStatusProvider);
    return inserted;
  }

  /// Повторный опрос Google (для диагностики/ручного обновления).
  Future<int> sync() async {
    final n = await _ref.read(googleHealthApiProvider).sync();
    _ref.invalidate(googleHealthStatusProvider);
    return n;
  }

  Future<void> disconnect() async {
    await _ref.read(googleHealthApiProvider).disconnect();
    _ref.invalidate(googleHealthStatusProvider);
  }
}

final googleHealthControllerProvider =
    Provider<GoogleHealthController>((ref) => GoogleHealthController(ref));
