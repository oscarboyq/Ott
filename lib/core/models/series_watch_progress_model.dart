import 'package:equatable/equatable.dart';
import 'package:video/core/utils/safe_type_parsers.dart';

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

  factory SeriesWatchProgressModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return SeriesWatchProgressModel(
      id: json['id']?.toString() ?? '',
      userId: (json['user_id'] ?? json['userId'])?.toString() ?? '',
      seriesId: (json['series_id'] ?? json['seriesId'])?.toString() ?? '',
      seasonId: (json['season_id'] ?? json['seasonId'])?.toString() ?? '',
      episodeId: (json['episode_id'] ?? json['episodeId'])?.toString() ?? '',
      positionSeconds: parseIntSafe(
        json['position_seconds'] ?? json['positionSeconds'],
        0,
      ),
      isCompleted: parseBoolSafe(
        json['is_completed'] ?? json['isCompleted'],
        false,
      ),
      lastWatchedAt: parseDateTimeSafe(
        json['last_watched_at'] ?? json['lastWatchedAt'],
      ),
      createdAt: parseDateTimeSafe(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTimeSafe(json['updated_at'] ?? json['updatedAt']),
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
