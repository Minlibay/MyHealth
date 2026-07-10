import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/evaluation_api.dart';
import '../api/metrics_api.dart';
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

/// Состояние аутентификации. null — пользователь не вошёл (локальный режим).
/// Токен подставляется в [ApiClient] и сохраняется в защищённом хранилище.
class AuthController extends AsyncNotifier<AuthSession?> {
  static const _key = 'auth_session_v1';
  final _storage = const FlutterSecureStorage();

  @override
  Future<AuthSession?> build() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final session =
        AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    ref.read(apiClientProvider).token = session.token;
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
    await _storage.delete(key: _key);
    ref.read(apiClientProvider).token = null;
    state = const AsyncData(null);
  }

  Future<void> _persist(AuthSession s) async {
    ref.read(apiClientProvider).token = s.token;
    await _storage.write(
      key: _key,
      value: jsonEncode(
          {'token': s.token, 'userId': s.userId, 'email': s.email}),
    );
    state = AsyncData(s);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);
