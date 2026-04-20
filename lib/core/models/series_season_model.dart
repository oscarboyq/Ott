import 'package:equatable/equatable.dart';

class SeriesSeasonModel extends Equatable {
  const SeriesSeasonModel({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.title,
    required this.description,
    required this.posterUrl,
    required this.createdAt,
    required this.updatedAt,
    this.releaseDate,
    this.episodeCount = 0,
  });

  final String id;
  final String seriesId;
  final int seasonNumber;
  final String title;
  final String description;
  final String posterUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? releaseDate;
  final int episodeCount;

  factory SeriesSeasonModel.fromJson(Map<String, dynamic> json) {
    return SeriesSeasonModel(
      id: json['id'] as String,
      seriesId: (json['series_id'] ?? json['seriesId']) as String,
      seasonNumber:
          (json['season_number'] ?? json['seasonNumber']) as int? ?? 1,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      posterUrl: (json['poster_url'] ?? json['posterUrl']) as String? ?? '',
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
      episodeCount:
          (json['episode_count'] ?? json['episodeCount']) as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    seriesId,
    seasonNumber,
    title,
    description,
    posterUrl,
    createdAt,
    updatedAt,
    releaseDate,
    episodeCount,
  ];
}
