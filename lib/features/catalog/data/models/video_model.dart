import 'package:video/features/catalog/domain/entities/video_item.dart';

class VideoModel {
  const VideoModel({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.category,
    required this.durationLabel,
    required this.releaseLabel,
    required this.accentHex,
    required this.videoUrl,
    required this.accessLevel,
    this.isFeatured = false,
    this.isPublished = true,
  });

  final String id;
  final String title;
  final String tagline;
  final String description;
  final String category;
  final String durationLabel;
  final String releaseLabel;
  final String accentHex;
  final String videoUrl;
  final VideoAccessLevel accessLevel;
  final bool isFeatured;
  final bool isPublished;

  VideoModel copyWith({
    String? id,
    String? title,
    String? tagline,
    String? description,
    String? category,
    String? durationLabel,
    String? releaseLabel,
    String? accentHex,
    String? videoUrl,
    VideoAccessLevel? accessLevel,
    bool? isFeatured,
    bool? isPublished,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      category: category ?? this.category,
      durationLabel: durationLabel ?? this.durationLabel,
      releaseLabel: releaseLabel ?? this.releaseLabel,
      accentHex: accentHex ?? this.accentHex,
      videoUrl: videoUrl ?? this.videoUrl,
      accessLevel: accessLevel ?? this.accessLevel,
      isFeatured: isFeatured ?? this.isFeatured,
      isPublished: isPublished ?? this.isPublished,
    );
  }

  VideoItem toEntity() {
    return VideoItem(
      id: id,
      title: title,
      tagline: tagline,
      description: description,
      category: category,
      durationLabel: durationLabel,
      releaseLabel: releaseLabel,
      accentHex: accentHex,
      videoUrl: videoUrl,
      accessLevel: accessLevel,
      isFeatured: isFeatured,
      isPublished: isPublished,
    );
  }
}
