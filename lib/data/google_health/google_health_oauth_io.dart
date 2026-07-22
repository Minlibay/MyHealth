import 'dart:io' show Platform;

import 'package:flutter_appauth/flutter_appauth.dart';

import 'google_health_oauth.dart';

// iOS OAuth-клиент Google (нативный, без секрета). Android-клиента ещё
// нет — там вход отключён (см. googleHealthSupported).
const _iosClientId =
    '802228692661-o3a1k71dfr61naj9njecd80vopnj09im.apps.googleusercontent.com';
const _iosRedirect =
    'com.googleusercontent.apps.802228692661-o3a1k71dfr61naj9njecd80vopnj09im:/oauth2redirect';

const _scopes = [
  'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly',
  'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly',
  'https://www.googleapis.com/auth/googlehealth.sleep.readonly',
  'https://www.googleapis.com/auth/googlehealth.nutrition.readonly',
];

/// Пока поддерживается только iOS (есть OAuth-клиент). Android появится
/// после регистрации Android-клиента (package + SHA-1).
bool get googleHealthSupported => Platform.isIOS;

/// Запускает Google OAuth (PKCE, offline) и возвращает refresh-токен.
/// null — пользователь отменил или платформа не поддержана.
Future<GoogleHealthAuthResult?> signInGoogleHealth() async {
  if (!googleHealthSupported) return null;
  const appAuth = FlutterAppAuth();

  final result = await appAuth.authorizeAndExchangeCode(
    AuthorizationTokenRequest(
      _iosClientId,
      _iosRedirect,
      issuer: 'https://accounts.google.com',
      scopes: _scopes,
      // offline access + принудительный consent, чтобы Google выдал
      // refresh-токен (иначе при повторном входе его может не быть).
      promptValues: ['consent'],
      additionalParameters: const {'access_type': 'offline'},
    ),
  );

  final refresh = result.refreshToken;
  if (refresh == null || refresh.isEmpty) return null;
  return GoogleHealthAuthResult(
    refreshToken: refresh,
    scopes: result.scopes?.join(' '),
  );
}
