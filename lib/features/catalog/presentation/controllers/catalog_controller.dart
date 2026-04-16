import 'package:flutter/foundation.dart';
import 'package:video/features/catalog/domain/entities/video_item.dart';
import 'package:video/features/catalog/domain/usecases/get_catalog.dart';

enum CatalogFilter { all, freeOnly, premiumOnly }

class CatalogController extends ChangeNotifier {
  CatalogController({required GetCatalogUseCase getCatalogUseCase})
    : _getCatalogUseCase = getCatalogUseCase {
    loadCatalog();
  }

  final GetCatalogUseCase _getCatalogUseCase;

  List<VideoItem> _videos = const <VideoItem>[];
  bool _isLoading = true;
  String? _errorMessage;
  CatalogFilter _activeFilter = CatalogFilter.all;

  List<VideoItem> get videos => _videos;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  CatalogFilter get activeFilter => _activeFilter;

  List<VideoItem> get visibleVideos {
    switch (_activeFilter) {
      case CatalogFilter.all:
        return _videos;
      case CatalogFilter.freeOnly:
        return _videos.where((VideoItem video) => video.isFree).toList();
      case CatalogFilter.premiumOnly:
        return _videos.where((VideoItem video) => !video.isFree).toList();
    }
  }

  int get freeCount => _videos.where((VideoItem video) => video.isFree).length;

  int get premiumCount =>
      _videos.where((VideoItem video) => !video.isFree).length;

  Future<void> loadCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _videos = await _getCatalogUseCase();
    } catch (_) {
      _errorMessage = 'We could not load the catalog right now.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(CatalogFilter filter) {
    if (_activeFilter == filter) {
      return;
    }

    _activeFilter = filter;
    notifyListeners();
  }

  VideoItem? findById(String id) {
    for (final VideoItem video in _videos) {
      if (video.id == id) {
        return video;
      }
    }

    return null;
  }
}
