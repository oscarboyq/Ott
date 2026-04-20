import 'package:equatable/equatable.dart';

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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      isAdmin: json['is_admin'] as bool? ?? json['isAdmin'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      premiumExpiresAt: json['premiumExpiresAt'] != null
          ? DateTime.parse(json['premiumExpiresAt'] as String)
          : null,
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
