import 'package:flutter/foundation.dart';
import 'package:video/features/admin/domain/entities/admin_video_draft.dart';
import 'package:video/features/admin/domain/usecases/create_video.dart';
import 'package:video/features/admin/domain/usecases/get_admin_catalog.dart';
import 'package:video/features/admin/domain/usecases/update_featured_status.dart';
import 'package:video/features/admin/domain/usecases/update_publish_status.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';

class AdminCatalogController extends ChangeNotifier {
  AdminCatalogController({
    required GetAdminCatalogUseCase getAdminCatalogUseCase,
    required CreateVideoUseCase createVideoUseCase,
    required UpdatePublishStatusUseCase updatePublishStatusUseCase,
    required UpdateFeaturedStatusUseCase updateFeaturedStatusUseCase,
  }) : _getAdminCatalogUseCase = getAdminCatalogUseCase,
       _createVideoUseCase = createVideoUseCase,
       _updatePublishStatusUseCase = updatePublishStatusUseCase,
       _updateFeaturedStatusUseCase = updateFeaturedStatusUseCase {
    loadCatalog();
  }

  final GetAdminCatalogUseCase _getAdminCatalogUseCase;
  final CreateVideoUseCase _createVideoUseCase;
  final UpdatePublishStatusUseCase _updatePublishStatusUseCase;
  final UpdateFeaturedStatusUseCase _updateFeaturedStatusUseCase;

  List<VideoItem> _videos = const <VideoItem>[];
  bool _isLoading = true;
  bool _isWorking = false;
  String? _errorMessage;

  List<VideoItem> get videos => _videos;

  bool get isLoading => _isLoading;

  bool get isWorking => _isWorking;

  String? get errorMessage => _errorMessage;

  int get totalCount => _videos.length;

  int get publishedCount =>
      _videos.where((VideoItem video) => video.isPublished).length;

  int get draftCount =>
      _videos.where((VideoItem video) => !video.isPublished).length;

  int get premiumCount =>
      _videos.where((VideoItem video) => !video.isFree).length;

  Future<void> loadCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _videos = await _getAdminCatalogUseCase();
    } catch (_) {
      _errorMessage = 'We could not load the admin catalog.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createVideo(AdminVideoDraft draft) {
    return _runAction(() => _createVideoUseCase(draft));
  }

  Future<void> updatePublishStatus({
    required String videoId,
    required bool isPublished,
  }) {
    return _runAction(
      () => _updatePublishStatusUseCase(
        videoId: videoId,
        isPublished: isPublished,
      ),
    );
  }

  Future<void> updateFeaturedStatus({
    required String videoId,
    required bool isFeatured,
  }) {
    return _runAction(
      () => _updateFeaturedStatusUseCase(
        videoId: videoId,
        isFeatured: isFeatured,
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isWorking) {
      return;
    }

    _isWorking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      _videos = await _getAdminCatalogUseCase();
    } catch (_) {
      _errorMessage = 'The admin action could not be completed.';
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }
}
