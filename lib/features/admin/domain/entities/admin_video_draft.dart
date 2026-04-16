import 'package:equatable/equatable.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';

class AdminVideoDraft extends Equatable {
  const AdminVideoDraft({
    required this.title,
    required this.tagline,
    required this.description,
    required this.category,
    required this.durationLabel,
    required this.releaseLabel,
    required this.accentHex,
    required this.videoUrl,
    required this.accessLevel,
    required this.isFeatured,
    required this.isPublished,
  });

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

  @override
  List<Object?> get props => <Object?>[
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
