import 'package:video/features/admin/domain/entities/admin_video_draft.dart';
import 'package:video/features/admin/domain/repositories/admin_video_repository.dart';
import 'package:video/features/catalog/data/datasources/video_data_source.dart';
import 'package:video/features/catalog/data/models/video_model.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';

class MockAdminVideoRepository implements AdminVideoRepository {
  const MockAdminVideoRepository(this._videoDataSource);

  final VideoDataSource _videoDataSource;

  @override
  Future<void> createVideo(AdminVideoDraft draft) {
    return _videoDataSource.createVideo(
      VideoModel(
        id: _buildId(draft.title),
        title: draft.title.trim(),
        tagline: draft.tagline.trim(),
        description: draft.description.trim(),
        category: draft.category.trim(),
        durationLabel: draft.durationLabel.trim(),
        releaseLabel: draft.releaseLabel.trim(),
        accentHex: draft.accentHex.trim(),
        videoUrl: draft.videoUrl.trim(),
        accessLevel: draft.accessLevel,
        isFeatured: draft.isFeatured,
        isPublished: draft.isPublished,
      ),
    );
  }

  @override
  Future<List<VideoItem>> getAdminCatalog() async {
    final List<VideoModel> models = await _videoDataSource.getAdminCatalog();
    return models
        .map((VideoModel model) => model.toEntity())
        .toList(growable: false);
  }

  @override
  Future<void> updateFeaturedStatus({
    required String videoId,
    required bool isFeatured,
  }) {
    return _videoDataSource.updateFeaturedStatus(
      videoId: videoId,
      isFeatured: isFeatured,
    );
  }

  @override
  Future<void> updatePublishStatus({
    required String videoId,
    required bool isPublished,
  }) {
    return _videoDataSource.updatePublishStatus(
      videoId: videoId,
      isPublished: isPublished,
    );
  }

  String _buildId(String title) {
    final String slug = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final String base = slug.isEmpty ? 'video' : slug;
    return '$base-${DateTime.now().millisecondsSinceEpoch}';
  }
}
