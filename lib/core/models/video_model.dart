import 'package:equatable/equatable.dart';

enum VideoQuality { sd, hd, fullHd, fourK }

class VideoModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final String genre;
  final double rating;
  final int ratingCount;
  final int duration; // in seconds
  final int viewCount;
  final bool requiresPremium;
  final bool isReel;
  final bool isFeatured;
  final DateTime releaseDate;
  final DateTime createdAt;
  final String? director;
  final List<String>? cast;
  final List<VideoQuality>? availableQualities;

  const VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.genre,
    required this.rating,
    required this.ratingCount,
    required this.duration,
    required this.viewCount,
    required this.requiresPremium,
    this.isReel = false,
    this.isFeatured = false,
    required this.releaseDate,
    required this.createdAt,
    this.director,
    this.cast,
    this.availableQualities,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      // Supabase returns snake_case column names
      thumbnailUrl:
          (json['thumbnail_url'] ?? json['thumbnailUrl']) as String? ?? '',
      videoUrl: (json['video_url'] ?? json['videoUrl']) as String? ?? '',
      // Supabase uses 'category'; legacy JSON uses 'genre'
      genre: (json['category'] ?? json['genre']) as String? ?? '',
      rating: ((json['rating'] as num?) ?? 0).toDouble(),
      ratingCount: (json['rating_count'] ?? json['ratingCount']) as int? ?? 0,
      // Supabase uses 'duration_seconds'; legacy uses 'duration'
      duration: (json['duration_seconds'] ?? json['duration']) as int? ?? 0,
      // Supabase uses 'views_count'; legacy uses 'viewCount'
      viewCount: (json['views_count'] ?? json['viewCount']) as int? ?? 0,
      // Supabase uses 'is_free' (free = !requiresPremium)
      requiresPremium:
          json['requiresPremium'] as bool? ??
          !(json['is_free'] as bool? ?? true),
      isReel: (json['is_reel'] ?? json['isReel']) as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
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
      director: json['director'] as String?,
      cast: List<String>.from(json['cast'] as List? ?? []),
      availableQualities: (json['availableQualities'] as List?)
          ?.map((q) => VideoQuality.values.byName(q as String))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'genre': genre,
      'rating': rating,
      'ratingCount': ratingCount,
      'duration': duration,
      'viewCount': viewCount,
      'requiresPremium': requiresPremium,
      'isReel': isReel,
      'isFeatured': isFeatured,
      'releaseDate': releaseDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'director': director,
      'cast': cast,
      'availableQualities': availableQualities?.map((q) => q.name).toList(),
    };
  }

  VideoModel copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? videoUrl,
    String? genre,
    double? rating,
    int? ratingCount,
    int? duration,
    int? viewCount,
    bool? requiresPremium,
    bool? isReel,
    bool? isFeatured,
    DateTime? releaseDate,
    DateTime? createdAt,
    String? director,
    List<String>? cast,
    List<VideoQuality>? availableQualities,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      genre: genre ?? this.genre,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      duration: duration ?? this.duration,
      viewCount: viewCount ?? this.viewCount,
      requiresPremium: requiresPremium ?? this.requiresPremium,
      isReel: isReel ?? this.isReel,
      isFeatured: isFeatured ?? this.isFeatured,
      releaseDate: releaseDate ?? this.releaseDate,
      createdAt: createdAt ?? this.createdAt,
      director: director ?? this.director,
      cast: cast ?? this.cast,
      availableQualities: availableQualities ?? this.availableQualities,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    thumbnailUrl,
    videoUrl,
    genre,
    rating,
    ratingCount,
    duration,
    viewCount,
    requiresPremium,
    isReel,
    isFeatured,
    releaseDate,
    createdAt,
    director,
    cast,
    availableQualities,
  ];
}
