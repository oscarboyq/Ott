import 'package:equatable/equatable.dart';

class AppSession extends Equatable {
  const AppSession({
    required this.isAuthenticated,
    required this.hasPremiumAccess,
    this.userId,
    this.displayName,
  });

  const AppSession.guest()
    : isAuthenticated = false,
      hasPremiumAccess = false,
      userId = null,
      displayName = null;

  const AppSession.authenticated({
    required this.userId,
    required this.displayName,
    this.hasPremiumAccess = false,
  }) : isAuthenticated = true;

  final bool isAuthenticated;
  final bool hasPremiumAccess;
  final String? userId;
  final String? displayName;

  AppSession copyWith({
    bool? isAuthenticated,
    bool? hasPremiumAccess,
    String? userId,
    String? displayName,
  }) {
    return AppSession(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasPremiumAccess: hasPremiumAccess ?? this.hasPremiumAccess,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    isAuthenticated,
    hasPremiumAccess,
    userId,
    displayName,
  ];
}
