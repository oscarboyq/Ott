import 'package:equatable/equatable.dart';
import 'package:video/core/models/video_model.dart';

class WatchHistoryItemModel extends Equatable {
  const WatchHistoryItemModel({
    required this.id,
    required this.videoId,
    required this.watchedAt,
    required this.durationWatchedSeconds,
    required this.video,
  });

  final String id;
  final String videoId;
  final DateTime watchedAt;
  final int durationWatchedSeconds;
  final VideoModel video;

  double get progress {
    if (video.duration <= 0) {
      return 0;
    }

    final ratio = durationWatchedSeconds / video.duration;
    return ratio.clamp(0, 1).toDouble();
  }

  bool get hasResumePosition {
    return durationWatchedSeconds > 0 &&
        durationWatchedSeconds < video.duration;
  }

  factory WatchHistoryItemModel.fromRemoteJson(Map<String, dynamic> json) {
    final videoJson = Map<String, dynamic>.from(
      (json['videos'] ?? json['video'] ?? <String, dynamic>{})
          as Map<dynamic, dynamic>,
    );

    return WatchHistoryItemModel(
      id: json['id'] as String,
      videoId: (json['video_id'] ?? json['videoId']) as String,
      watchedAt: DateTime.parse(
        (json['watched_at'] ?? json['watchedAt']) as String,
      ),
      durationWatchedSeconds:
          (json['duration_watched_seconds'] ?? json['durationWatchedSeconds'])
              as int? ??
          0,
      video: VideoModel.fromJson(videoJson),
    );
  }

  factory WatchHistoryItemModel.fromLocalJson(Map<String, dynamic> json) {
    return WatchHistoryItemModel(
      id: json['id'] as String,
      videoId: json['videoId'] as String,
      watchedAt: DateTime.parse(json['watchedAt'] as String),
      durationWatchedSeconds: json['durationWatchedSeconds'] as int? ?? 0,
      video: VideoModel.fromJson(
        Map<String, dynamic>.from(json['video'] as Map<dynamic, dynamic>),
      ),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'videoId': videoId,
      'watchedAt': watchedAt.toIso8601String(),
      'durationWatchedSeconds': durationWatchedSeconds,
      'video': video.toJson(),
    };
  }

  WatchHistoryItemModel copyWith({
    String? id,
    String? videoId,
    DateTime? watchedAt,
    int? durationWatchedSeconds,
    VideoModel? video,
  }) {
    return WatchHistoryItemModel(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      watchedAt: watchedAt ?? this.watchedAt,
      durationWatchedSeconds:
          durationWatchedSeconds ?? this.durationWatchedSeconds,
      video: video ?? this.video,
    );
  }

  @override
  List<Object?> get props => [
    id,
    videoId,
    watchedAt,
    durationWatchedSeconds,
    video,
  ];
}
