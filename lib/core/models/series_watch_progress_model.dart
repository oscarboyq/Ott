import 'package:equatable/equatable.dart';

class SeriesWatchProgressModel extends Equatable {
  const SeriesWatchProgressModel({
    required this.id,
    required this.userId,
    required this.seriesId,
    required this.seasonId,
    required this.episodeId,
    required this.positionSeconds,
    required this.isCompleted,
    required this.lastWatchedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String seriesId;
  final String seasonId;
  final String episodeId;
  final int positionSeconds;
  final bool isCompleted;
  final DateTime lastWatchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SeriesWatchProgressModel.fromJson(Map<String, dynamic> json) {
    return SeriesWatchProgressModel(
      id: json['id'] as String,
      userId: (json['user_id'] ?? json['userId']) as String,
      seriesId: (json['series_id'] ?? json['seriesId']) as String,
      seasonId: (json['season_id'] ?? json['seasonId']) as String,
      episodeId: (json['episode_id'] ?? json['episodeId']) as String,
      positionSeconds:
          (json['position_seconds'] ?? json['positionSeconds']) as int? ?? 0,
      isCompleted:
          (json['is_completed'] ?? json['isCompleted']) as bool? ?? false,
      lastWatchedAt: DateTime.parse(
        (json['last_watched_at'] ?? json['lastWatchedAt']) as String,
      ),
      createdAt: DateTime.parse(
        (json['created_at'] ?? json['createdAt']) as String,
      ),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? json['updatedAt']) as String,
      ),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    seriesId,
    seasonId,
    episodeId,
    positionSeconds,
    isCompleted,
    lastWatchedAt,
    createdAt,
    updatedAt,
  ];
}
