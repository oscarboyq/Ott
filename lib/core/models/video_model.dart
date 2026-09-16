import 'package:equatable/equatable.dart';
import 'package:video/core/utils/safe_type_parsers.dart';

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
  final String mediaProvider;
  final String? providerVideoId;
  final String mediaStatus;
  final int processingProgress;
  final String? mediaError;
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
    this.mediaProvider = 'external',
    this.providerVideoId,
    this.mediaStatus = 'ready',
    this.processingProgress = 100,
    this.mediaError,
    required this.releaseDate,
    required this.createdAt,
    this.director,
    this.cast,
    this.availableQualities,
  });

  factory VideoModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);

    final bool requiresPremium;
    if (json.containsKey('requiresPremium') && json['requiresPremium'] != null) {
      requiresPremium = parseBoolSafe(json['requiresPremium']);
    } else if (json.containsKey('is_free') && json['is_free'] != null) {
      requiresPremium = !parseBoolSafe(json['is_free'], true);
    } else {
      requiresPremium = false;
    }

    List<VideoQuality>? qualities;
    final qualitiesRaw =
        json['availableQualities'] ?? json['available_qualities'];
    if (qualitiesRaw is List) {
      qualities = [];
      for (final q in qualitiesRaw) {
        if (q is String) {
          try {
            qualities.add(VideoQuality.values.byName(q));
          } catch (_) {}
        }
      }
    }

    return VideoModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      description: json['description']?.toString() ?? '',
      thumbnailUrl:
          (json['thumbnail_url'] ?? json['thumbnailUrl'])?.toString() ?? '',
      videoUrl: (json['video_url'] ?? json['videoUrl'])?.toString() ?? '',
      genre: (json['category'] ?? json['genre'])?.toString() ?? '',
      rating: parseDoubleSafe(json['rating'], 0.0),
      ratingCount:
          parseIntSafe(json['rating_count'] ?? json['ratingCount'], 0),
      duration:
          parseIntSafe(json['duration_seconds'] ?? json['duration'], 0),
      viewCount: parseIntSafe(json['views_count'] ?? json['viewCount'], 0),
      requiresPremium: requiresPremium,
      isReel: parseBoolSafe(json['is_reel'] ?? json['isReel'], false),
      isFeatured:
          parseBoolSafe(json['is_featured'] ?? json['isFeatured'], false),
      mediaProvider: json['media_provider']?.toString() ?? 'external',
      providerVideoId: json['provider_video_id']?.toString(),
      mediaStatus: json['media_status']?.toString() ?? 'ready',
      processingProgress: parseIntSafe(json['processing_progress'], 100),
      mediaError: json['media_error']?.toString(),
      releaseDate: parseDateTimeSafe(
        json['release_date'] ?? json['releaseDate'],
        DateTime(2000),
      ),
      createdAt: parseDateTimeSafe(json['created_at'] ?? json['createdAt']),
      director: json['director']?.toString(),
      cast: json['cast'] != null ? parseStringListSafe(json['cast']) : null,
      availableQualities: qualities,
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
      'mediaProvider': mediaProvider,
      'providerVideoId': providerVideoId,
      'mediaStatus': mediaStatus,
      'processingProgress': processingProgress,
      'mediaError': mediaError,
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
    String? mediaProvider,
    String? providerVideoId,
    String? mediaStatus,
    int? processingProgress,
    String? mediaError,
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
      mediaProvider: mediaProvider ?? this.mediaProvider,
      providerVideoId: providerVideoId ?? this.providerVideoId,
      mediaStatus: mediaStatus ?? this.mediaStatus,
      processingProgress: processingProgress ?? this.processingProgress,
      mediaError: mediaError ?? this.mediaError,
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
    mediaProvider,
    providerVideoId,
    mediaStatus,
    processingProgress,
    mediaError,
    releaseDate,
    createdAt,
    director,
    cast,
    availableQualities,
  ];
}
