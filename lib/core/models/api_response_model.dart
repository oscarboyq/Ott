import 'package:equatable/equatable.dart';

class ApiResponseModel<T> extends Equatable {
  final bool success;
  final String? message;
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResponseModel({
    required this.success,
    this.message,
    this.data,
    this.error,
    this.statusCode,
  });

  factory ApiResponseModel.fromJson(
    Map<String, dynamic> json, {
    required T Function(dynamic) fromJsonT,
  }) {
    return ApiResponseModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      error: json['error'] as String?,
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson({
    required Map<String, dynamic> Function(T) toJsonT,
  }) {
    return {
      'success': success,
      'message': message,
      'data': data != null ? toJsonT(data as T) : null,
      'error': error,
      'statusCode': statusCode,
    };
  }

  @override
  List<Object?> get props => [success, message, data, error, statusCode];
}
