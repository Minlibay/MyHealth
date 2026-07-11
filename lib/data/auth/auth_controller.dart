import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/evaluation_api.dart';
import '../api/insights_api.dart';
import '../api/metrics_api.dart';
import '../api/sleep_api.dart';
import '../api/user_api.dart';
import '../api/workouts_api.dart';
import 'auth_session.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authApiProvider =
    Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

final metricsApiProvider =
    Provider<MetricsApi>((ref) => MetricsApi(ref.watch(apiClientProvider)));

final evaluationApiProvider =
    Provider<EvaluationApi>((ref) => EvaluationApi(ref.watch(apiClientProvider)));

final workoutsApiProvider =
    Provider<WorkoutsApi>((ref) => WorkoutsApi(ref.watch(apiClientProvider)));

final userApiProvider =
    Provider<UserApi>((ref) => UserApi(ref.watch(apiClientProvider)));

final insightsApiProvider =
    Provider<InsightsApi>((ref) => InsightsApi(ref.watch(apiClientProvider)));

final sleepApiProvider =
    Provider<SleepApi>((ref) => SleepApi(ref.watch(apiClientProvider)));

/// Состояние аутентификации. null — пользователь не вошёл (локальный режим).
/// Токен подставляется в [ApiClient] и сохраняется в защищённом хранилище.
class AuthController extends AsyncNotifier<AuthSession?> {
  static const _key = 'auth_session_v1';
  final _storage = const FlutterSecureStorage();

  @override
  Future<AuthSession?> build() async {
    final client = ref.read(apiClientProvider);
    // Ротация токенов происходит внутри ApiClient — сохраняем новую пару.
    client.onTokensRefreshed = (token, refresh) {
      final current = state.value;
      if (current == null) return;
      _persist(current.copyWith(token: token, refreshToken: refresh));
    };
    // Refresh отвергнут сервером — локальная сессия больше не действительна.
    client.onSessionExpired = () {
      _storage.delete(key: _key);
      state = const AsyncData(null);
    };

    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final session =
        AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    client.token = session.token;
    client.refreshToken = session.refreshToken;
    return session;
  }

  Future<void> signIn(String email, String password) async {
    final s = await ref.read(authApiProvider).login(email.trim(), password);
    await _persist(s);
  }

  Future<void> signUp(String email, String password, String? displayName) async {
    final s = await ref
        .read(authApiProvider)
        .register(email.trim(), password, displayName: displayName);
    await _persist(s);
  }

  Future<void> signOut() async {
    // Отзываем refresh-токен на сервере (best-effort).
    final refresh = state.value?.refreshToken;
    if (refresh != null) {
      await ref.read(authApiProvider).logout(refresh);
    }
    await _storage.delete(key: _key);
    final client = ref.read(apiClientProvider);
    client.token = null;
    client.refreshToken = null;
    state = const AsyncData(null);
  }

  Future<void> _persist(AuthSession s) async {
    final client = ref.read(apiClientProvider);
    client.token = s.token;
    client.refreshToken = s.refreshToken;
    await _storage.write(key: _key, value: jsonEncode(s.toJson()));
    state = AsyncData(s);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);
