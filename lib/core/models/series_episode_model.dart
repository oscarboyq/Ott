import 'package:equatable/equatable.dart';
import 'package:video/core/utils/safe_type_parsers.dart';

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
    this.mediaProvider,
    this.providerVideoId,
    this.mediaStatus,
    this.processingProgress,
    this.mediaError,
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

  // Bunny Stream media provider fields (mirrors VideoModel)
  final String? mediaProvider;
  final String? providerVideoId;
  final String? mediaStatus;
  final int? processingProgress;
  final String? mediaError;

  bool get isBunnyEpisode => mediaProvider == 'bunny';

  factory SeriesEpisodeModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);

    final bool requiresPremium;
    if (json.containsKey('requiresPremium') && json['requiresPremium'] != null) {
      requiresPremium = parseBoolSafe(json['requiresPremium']);
    } else if (json.containsKey('is_free') && json['is_free'] != null) {
      requiresPremium = !parseBoolSafe(json['is_free'], false);
    } else {
      requiresPremium = true;
    }

    return SeriesEpisodeModel(
      id: json['id']?.toString() ?? '',
      seriesId:
          (json['series_id'] ?? json['seriesId'])?.toString() ?? '',
      seasonId:
          (json['season_id'] ?? json['seasonId'])?.toString() ?? '',
      episodeNumber: parseIntSafe(
        json['episode_number'] ?? json['episodeNumber'],
        1,
      ),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnailUrl:
          (json['thumbnail_url'] ?? json['thumbnailUrl'])?.toString() ?? '',
      videoUrl: (json['video_url'] ?? json['videoUrl'])?.toString() ?? '',
      duration:
          parseIntSafe(json['duration_seconds'] ?? json['duration'], 0),
      createdAt: parseDateTimeSafe(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTimeSafe(json['updated_at'] ?? json['updatedAt']),
      releaseDate: parseDateTimeNullableSafe(
        json['release_date'] ?? json['releaseDate'],
      ),
      requiresPremium: requiresPremium,
      viewCount: parseIntSafe(json['views_count'] ?? json['viewCount'], 0),
      mediaProvider:
          (json['media_provider'] ?? json['mediaProvider'])?.toString(),
      providerVideoId:
          (json['provider_video_id'] ?? json['providerVideoId'])?.toString(),
      mediaStatus:
          (json['media_status'] ?? json['mediaStatus'])?.toString(),
      processingProgress: () {
        final raw =
            json['processing_progress'] ?? json['processingProgress'];
        if (raw == null) return null;
        return parseIntSafe(raw, 0);
      }(),
      mediaError:
          (json['media_error'] ?? json['mediaError'])?.toString(),
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
      if (mediaProvider != null) 'mediaProvider': mediaProvider,
      if (providerVideoId != null) 'providerVideoId': providerVideoId,
      if (mediaStatus != null) 'mediaStatus': mediaStatus,
      if (processingProgress != null) 'processingProgress': processingProgress,
      if (mediaError != null) 'mediaError': mediaError,
    };
  }

  SeriesEpisodeModel copyWith({
    String? id,
    String? seriesId,
    String? seasonId,
    int? episodeNumber,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? videoUrl,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? releaseDate,
    bool? requiresPremium,
    int? viewCount,
    String? mediaProvider,
    String? providerVideoId,
    String? mediaStatus,
    int? processingProgress,
    String? mediaError,
  }) {
    return SeriesEpisodeModel(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      seasonId: seasonId ?? this.seasonId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      releaseDate: releaseDate ?? this.releaseDate,
      requiresPremium: requiresPremium ?? this.requiresPremium,
      viewCount: viewCount ?? this.viewCount,
      mediaProvider: mediaProvider ?? this.mediaProvider,
      providerVideoId: providerVideoId ?? this.providerVideoId,
      mediaStatus: mediaStatus ?? this.mediaStatus,
      processingProgress: processingProgress ?? this.processingProgress,
      mediaError: mediaError ?? this.mediaError,
    );
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
    mediaProvider,
    providerVideoId,
    mediaStatus,
    processingProgress,
    mediaError,
  ];
}
