import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:video/core/constants/app_config.dart';
import 'package:video/core/exceptions/app_exception.dart';

class HttpClient {
  late Dio _dio;
  static final HttpClient _instance = HttpClient._internal();

  factory HttpClient() {
    return _instance;
  }

  HttpClient._internal() {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        contentType: Headers.jsonContentType,
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
      ),
    );

    // Add pretty logger in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: true,
          error: true,
          compact: true,
        ),
      );
    }
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      throw _handleException(e as DioException);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      throw _handleException(e as DioException);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      throw _handleException(e as DioException);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } catch (e) {
      throw _handleException(e as DioException);
    }
  }

  AppException _handleException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return NetworkException('Request timeout. Please try again.');
      case DioExceptionType.badResponse:
        return _handleBadResponse(exception.response);
      case DioExceptionType.cancel:
        return NetworkException('Request cancelled.');
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return NetworkException('Network error. Please check your connection.');
      default:
        return UnknownException('An unexpected error occurred.');
    }
  }

  AppException _handleBadResponse(Response? response) {
    if (response == null) {
      return ServerException('Unknown server error', 500);
    }

    final statusCode = response.statusCode ?? 500;
    String message = response.statusMessage ?? 'Error';

    // Try to extract error message from response body
    if (response.data is Map<String, dynamic>) {
      message = response.data['message'] ?? message;
    }

    switch (statusCode) {
      case 400:
        return ValidationException(message);
      case 401:
      case 403:
        if (statusCode == 401) {
          return TokenExpiredException('Session expired. Please login again.');
        }
        return AuthException('Unauthorized access.');
      case 404:
        return ServerException('Resource not found.', statusCode);
      case 500:
      case 502:
      case 503:
        return ServerException(
          'Server error. Please try again later.',
          statusCode,
        );
      default:
        return ServerException(message, statusCode);
    }
  }

  void dispose() {
    _dio.close();
  }
}
