import 'package:equatable/equatable.dart';

enum VideoAccessLevel { free, premium }

class VideoItem extends Equatable {
  const VideoItem({
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

  bool get isFree => accessLevel == VideoAccessLevel.free;

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    tagline,
    description,
    category,
    durationLabel,
    releaseLabel,
    accentHex,
    videoUrl,
    accessLevel,
    isFeatured,
    isPublished,
  ];
}
