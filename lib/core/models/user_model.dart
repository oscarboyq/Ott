import 'package:equatable/equatable.dart';
import 'package:video/core/utils/safe_type_parsers.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String username;
  final String? profileImageUrl;
  final bool isPremium;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime? premiumExpiresAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.profileImageUrl,
    required bool isPremium,
    this.isAdmin = false,
    required this.createdAt,
    this.premiumExpiresAt,
  }) : isPremium = isPremium || isAdmin;

  factory UserModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: (json['username'] ?? json['user_name'])?.toString() ?? '',
      profileImageUrl:
          (json['profileImageUrl'] ?? json['profile_image_url'])?.toString(),
      isPremium: parseBoolSafe(
        json['isPremium'] ?? json['is_premium'],
        false,
      ),
      isAdmin: parseBoolSafe(
        json['isAdmin'] ?? json['is_admin'],
        false,
      ),
      createdAt:
          parseDateTimeSafe(json['createdAt'] ?? json['created_at']),
      premiumExpiresAt: parseDateTimeNullableSafe(
        json['premiumExpiresAt'] ?? json['premium_expires_at'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'isPremium': isPremium,
      'isAdmin': isAdmin,
      'createdAt': createdAt.toIso8601String(),
      'premiumExpiresAt': premiumExpiresAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? profileImageUrl,
    bool? isPremium,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? premiumExpiresAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isPremium: isPremium ?? this.isPremium,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    username,
    profileImageUrl,
    isPremium,
    isAdmin,
    createdAt,
    premiumExpiresAt,
  ];
}
