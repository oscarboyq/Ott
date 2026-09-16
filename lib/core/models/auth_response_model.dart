import 'package:equatable/equatable.dart';
import 'package:video/core/models/user_model.dart';

class AuthResponseModel extends Equatable {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return AuthResponseModel(
      accessToken:
          (json['accessToken'] ?? json['access_token'])?.toString() ?? '',
      refreshToken:
          (json['refreshToken'] ?? json['refresh_token'])?.toString() ?? '',
      user: json['user'] is Map
          ? UserModel.fromJson(json['user'] as Map)
          : UserModel(
              id: '',
              email: '',
              username: '',
              isPremium: false,
              createdAt: DateTime.now(),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, user];
}
