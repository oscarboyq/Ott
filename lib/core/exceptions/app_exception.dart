abstract class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message);
}

class AuthException extends AppException {
  AuthException(String message) : super(message);
}

class ValidationException extends AppException {
  ValidationException(String message) : super(message);
}

class ServerException extends AppException {
  final int statusCode;

  ServerException(String message, this.statusCode) : super(message);
}

class CacheException extends AppException {
  CacheException(String message) : super(message);
}

class UnknownException extends AppException {
  UnknownException(String message) : super(message);
}

class TokenExpiredException extends AuthException {
  TokenExpiredException(String message) : super(message);
}
