import 'package:flutter/foundation.dart';

/// Базовый адрес бэкенда для dev-окружения.
/// Android-эмулятор обращается к хосту через 10.0.2.2, остальные — localhost.
String get apiBaseUrl {
  if (kIsWeb) return 'http://localhost:5271';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:5271';
    default:
      return 'http://localhost:5271';
  }
}
