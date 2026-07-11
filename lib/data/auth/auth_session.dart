/// Данные авторизованной сессии (хранятся в защищённом хранилище).
class AuthSession {
  const AuthSession({
    required this.token,
    required this.refreshToken,
    required this.userId,
    required this.email,
  });

  /// Короткоживущий access-токен (JWT).
  final String token;

  /// Долгоживущий refresh-токен; ротируется при каждом обновлении.
  final String refreshToken;

  final String userId;
  final String email;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        // Старые сохранённые сессии (до refresh-токенов) — потребуют
        // повторного входа при первом 401.
        refreshToken: (json['refreshToken'] as String?) ?? '',
        userId: json['userId'] as String,
        email: json['email'] as String,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'refreshToken': refreshToken,
        'userId': userId,
        'email': email,
      };

  AuthSession copyWith({String? token, String? refreshToken}) => AuthSession(
        token: token ?? this.token,
        refreshToken: refreshToken ?? this.refreshToken,
        userId: userId,
        email: email,
      );
}

/// Ошибка обращения к API с человекочитаемым сообщением.
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
