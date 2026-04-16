import 'package:video/features/catalog/data/models/video_model.dart';

abstract class VideoDataSource {
  Future<List<VideoModel>> getCatalog();

  Future<List<VideoModel>> getAdminCatalog();

  Future<void> createVideo(VideoModel video);

  Future<void> updatePublishStatus({
    required String videoId,
    required bool isPublished,
  });

  Future<void> updateFeaturedStatus({
    required String videoId,
    required bool isFeatured,
  });
}
