import 'package:equatable/equatable.dart';
import 'package:video/core/utils/safe_type_parsers.dart';

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

  factory SeriesSeasonModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return SeriesSeasonModel(
      id: json['id']?.toString() ?? '',
      seriesId: (json['series_id'] ?? json['seriesId'])?.toString() ?? '',
      seasonNumber: parseIntSafe(
        json['season_number'] ?? json['seasonNumber'],
        1,
      ),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      posterUrl: (json['poster_url'] ?? json['posterUrl'])?.toString() ?? '',
      createdAt:
          parseDateTimeSafe(json['created_at'] ?? json['createdAt']),
      updatedAt:
          parseDateTimeSafe(json['updated_at'] ?? json['updatedAt']),
      releaseDate: parseDateTimeNullableSafe(
        json['release_date'] ?? json['releaseDate'],
      ),
      episodeCount: parseIntSafe(
        json['episode_count'] ?? json['episodeCount'],
        0,
      ),
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
