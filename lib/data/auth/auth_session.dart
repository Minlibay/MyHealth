/// Данные авторизованной сессии (хранятся в защищённом хранилище).
class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.email,
  });

  final String token;
  final String userId;
  final String email;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        userId: json['userId'] as String,
        email: json['email'] as String,
      );
}

/// Ошибка обращения к API с человекочитаемым сообщением.
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
