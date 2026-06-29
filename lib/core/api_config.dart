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
    // ВАЖНО: замени на свой боевой домен или всегда передавай --dart-define.
    return 'https://api.example.com';
  }

  if (kIsWeb) return 'http://localhost:5271';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5271';
  }
  return 'http://localhost:5271';
}
