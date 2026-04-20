import 'package:equatable/equatable.dart';

class SeriesEpisodeModel extends Equatable {
  const SeriesEpisodeModel({
    required this.id,
    required this.seriesId,
    required this.seasonId,
    required this.episodeNumber,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
    required this.createdAt,
    required this.updatedAt,
    this.releaseDate,
    this.requiresPremium = true,
    this.viewCount = 0,
  });

  final String id;
  final String seriesId;
  final String seasonId;
  final int episodeNumber;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final int duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? releaseDate;
  final bool requiresPremium;
  final int viewCount;

  factory SeriesEpisodeModel.fromJson(Map<String, dynamic> json) {
    return SeriesEpisodeModel(
      id: json['id'] as String,
      seriesId: (json['series_id'] ?? json['seriesId']) as String,
      seasonId: (json['season_id'] ?? json['seasonId']) as String,
      episodeNumber:
          (json['episode_number'] ?? json['episodeNumber']) as int? ?? 1,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl:
          (json['thumbnail_url'] ?? json['thumbnailUrl']) as String? ?? '',
      videoUrl: (json['video_url'] ?? json['videoUrl']) as String? ?? '',
      duration: (json['duration_seconds'] ?? json['duration']) as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'] as String)
          : json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : null,
      requiresPremium:
          json['requiresPremium'] as bool? ??
          !(json['is_free'] as bool? ?? false),
      viewCount: (json['views_count'] ?? json['viewCount']) as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seriesId': seriesId,
      'seasonId': seasonId,
      'episodeNumber': episodeNumber,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'duration': duration,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'releaseDate': releaseDate?.toIso8601String(),
      'requiresPremium': requiresPremium,
      'viewCount': viewCount,
    };
  }

  @override
  List<Object?> get props => [
    id,
    seriesId,
    seasonId,
    episodeNumber,
    title,
    description,
    thumbnailUrl,
    videoUrl,
    duration,
    createdAt,
    updatedAt,
    releaseDate,
    requiresPremium,
    viewCount,
  ];
}
