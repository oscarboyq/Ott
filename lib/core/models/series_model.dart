import 'package:equatable/equatable.dart';
import 'package:video/core/utils/safe_type_parsers.dart';

class SeriesModel extends Equatable {
  const SeriesModel({
    required this.id,
    required this.title,
    required this.description,
    required this.posterUrl,
    required this.backdropUrl,
    required this.tagline,
    required this.genre,
    required this.releaseDate,
    required this.createdAt,
    required this.updatedAt,
    this.slug,
    this.trailerUrl,
    this.isFeatured = false,
    this.isPublished = true,
    this.requiresPremium = true,
    this.viewCount = 0,
    this.seasonCount = 0,
    this.episodeCount = 0,
  });

  final String id;
  final String title;
  final String description;
  final String posterUrl;
  final String backdropUrl;
  final String tagline;
  final String genre;
  final DateTime releaseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? slug;
  final String? trailerUrl;
  final bool isFeatured;
  final bool isPublished;
  final bool requiresPremium;
  final int viewCount;
  final int seasonCount;
  final int episodeCount;

  factory SeriesModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);

    final bool requiresPremium;
    if (json.containsKey('requiresPremium') && json['requiresPremium'] != null) {
      requiresPremium = parseBoolSafe(json['requiresPremium']);
    } else if (json.containsKey('is_free') && json['is_free'] != null) {
      requiresPremium = !parseBoolSafe(json['is_free'], false);
    } else {
      requiresPremium = true;
    }

    return SeriesModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      posterUrl:
          (json['poster_url'] ?? json['posterUrl'])?.toString() ?? '',
      backdropUrl:
          (json['backdrop_url'] ?? json['backdropUrl'])?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      genre: (json['category'] ?? json['genre'])?.toString() ?? 'Series',
      releaseDate: parseDateTimeSafe(
        json['release_date'] ?? json['releaseDate'],
        DateTime(2000),
      ),
      createdAt: parseDateTimeSafe(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTimeSafe(json['updated_at'] ?? json['updatedAt']),
      slug: json['slug']?.toString(),
      trailerUrl: (json['trailer_url'] ?? json['trailerUrl'])?.toString(),
      isFeatured:
          parseBoolSafe(json['is_featured'] ?? json['isFeatured'], false),
      isPublished:
          parseBoolSafe(json['is_published'] ?? json['isPublished'], true),
      requiresPremium: requiresPremium,
      viewCount: parseIntSafe(json['views_count'] ?? json['viewCount'], 0),
      seasonCount:
          parseIntSafe(json['season_count'] ?? json['seasonCount'], 0),
      episodeCount:
          parseIntSafe(json['episode_count'] ?? json['episodeCount'], 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'tagline': tagline,
      'genre': genre,
      'releaseDate': releaseDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'slug': slug,
      'trailerUrl': trailerUrl,
      'isFeatured': isFeatured,
      'isPublished': isPublished,
      'requiresPremium': requiresPremium,
      'viewCount': viewCount,
      'seasonCount': seasonCount,
      'episodeCount': episodeCount,
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    posterUrl,
    backdropUrl,
    tagline,
    genre,
    releaseDate,
    createdAt,
    updatedAt,
    slug,
    trailerUrl,
    isFeatured,
    isPublished,
    requiresPremium,
    viewCount,
    seasonCount,
    episodeCount,
  ];
}
