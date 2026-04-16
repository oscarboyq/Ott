import 'package:video/features/admin/domain/entities/admin_video_draft.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';

abstract class AdminVideoRepository {
  Future<List<VideoItem>> getAdminCatalog();

  Future<void> createVideo(AdminVideoDraft draft);

  Future<void> updatePublishStatus({
    required String videoId,
    required bool isPublished,
  });

  Future<void> updateFeaturedStatus({
    required String videoId,
    required bool isFeatured,
  });
}
