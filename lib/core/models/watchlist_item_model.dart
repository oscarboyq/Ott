import 'package:equatable/equatable.dart';

class WatchlistItemModel extends Equatable {
  final String id;
  final String videoId;
  final String userId;
  final DateTime addedAt;
  final bool watched;
  final double watchProgress; // 0.0 to 1.0

  const WatchlistItemModel({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.addedAt,
    required this.watched,
    required this.watchProgress,
  });

  factory WatchlistItemModel.fromJson(Map<String, dynamic> json) {
    return WatchlistItemModel(
      id: json['id'] as String,
      videoId: json['videoId'] as String,
      userId: json['userId'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      watched: json['watched'] as bool? ?? false,
      watchProgress: (json['watchProgress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'userId': userId,
      'addedAt': addedAt.toIso8601String(),
      'watched': watched,
      'watchProgress': watchProgress,
    };
  }

  WatchlistItemModel copyWith({
    String? id,
    String? videoId,
    String? userId,
    DateTime? addedAt,
    bool? watched,
    double? watchProgress,
  }) {
    return WatchlistItemModel(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      addedAt: addedAt ?? this.addedAt,
      watched: watched ?? this.watched,
      watchProgress: watchProgress ?? this.watchProgress,
    );
  }

  @override
  List<Object?> get props => [
    id,
    videoId,
    userId,
    addedAt,
    watched,
    watchProgress,
  ];
}
