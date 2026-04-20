import 'package:equatable/equatable.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/models/series_model.dart';

class SeriesHistoryItemModel extends Equatable {
  const SeriesHistoryItemModel({
    required this.id,
    required this.userId,
    required this.seriesId,
    required this.seasonId,
    required this.episodeId,
    required this.positionSeconds,
    required this.isCompleted,
    required this.lastWatchedAt,
    required this.series,
    required this.episode,
  });

  final String id;
  final String userId;
  final String seriesId;
  final String seasonId;
  final String episodeId;
  final int positionSeconds;
  final bool isCompleted;
  final DateTime lastWatchedAt;
  final SeriesModel series;
  final SeriesEpisodeModel episode;

  double get progress {
    if (episode.duration <= 0) {
      return 0;
    }

    final ratio = positionSeconds / episode.duration;
    return ratio.clamp(0, 1).toDouble();
  }

  bool get hasResumePosition {
    return positionSeconds > 0 &&
        !isCompleted &&
        positionSeconds < episode.duration;
  }

  factory SeriesHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return SeriesHistoryItemModel(
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
      series: SeriesModel.fromJson(
        Map<String, dynamic>.from(json['series'] as Map<dynamic, dynamic>),
      ),
      episode: SeriesEpisodeModel.fromJson(
        Map<String, dynamic>.from(json['episode'] as Map<dynamic, dynamic>),
      ),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'userId': userId,
      'seriesId': seriesId,
      'seasonId': seasonId,
      'episodeId': episodeId,
      'positionSeconds': positionSeconds,
      'isCompleted': isCompleted,
      'lastWatchedAt': lastWatchedAt.toIso8601String(),
      'series': series.toJson(),
      'episode': episode.toJson(),
    };
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
    series,
    episode,
  ];
}
