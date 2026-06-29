import 'package:flutter/foundation.dart';

/// Адрес бэкенда.
///
/// Приоритет:
/// 1. `--dart-define=API_BASE_URL=https://api.домен` (прод/CI) — если задан;
/// 2. релизная сборка без override → боевой домен (заменить на свой);
/// 3. dev: localhost (Android-эмулятор — 10.0.2.2).
const _override = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_override.isNotEmpty) return _override;

  if (kReleaseMode) {
    // Боевой бэкенд (IP:порт). Лучше переопределять через --dart-define.
    // TODO: перейти на https://домен с TLS до публичного релиза.
    return 'http://185.40.4.195:53917';
  }

  if (kIsWeb) return 'http://localhost:5271';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5271';
  }
  return 'http://localhost:5271';
}
