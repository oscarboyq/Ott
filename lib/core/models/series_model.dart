import 'package:equatable/equatable.dart';

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

  factory SeriesModel.fromJson(Map<String, dynamic> json) {
    return SeriesModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      posterUrl: (json['poster_url'] ?? json['posterUrl']) as String? ?? '',
      backdropUrl:
          (json['backdrop_url'] ?? json['backdropUrl']) as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      genre: (json['category'] ?? json['genre']) as String? ?? 'Series',
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'] as String)
          : json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : DateTime(2000),
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
      slug: json['slug'] as String?,
      trailerUrl: (json['trailer_url'] ?? json['trailerUrl']) as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? true,
      requiresPremium:
          json['requiresPremium'] as bool? ??
          !(json['is_free'] as bool? ?? false),
      viewCount: (json['views_count'] ?? json['viewCount']) as int? ?? 0,
      seasonCount: (json['season_count'] ?? json['seasonCount']) as int? ?? 0,
      episodeCount:
          (json['episode_count'] ?? json['episodeCount']) as int? ?? 0,
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
