import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/providers/service_providers.dart';

// Video Catalog State
class VideoCatalogState {
  final List<VideoModel> videos;
  final bool isLoading;
  final String? errorMessage;
  final int currentPage;
  final String? selectedGenre;
  final bool hasMorePages;

  const VideoCatalogState({
    this.videos = const [],
    this.isLoading = false,
    this.errorMessage,
    this.currentPage = 1,
    this.selectedGenre,
    this.hasMorePages = true,
  });

  VideoCatalogState copyWith({
    List<VideoModel>? videos,
    bool? isLoading,
    String? errorMessage,
    int? currentPage,
    String? selectedGenre,
    bool? hasMorePages,
  }) {
    return VideoCatalogState(
      videos: videos ?? this.videos,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPage: currentPage ?? this.currentPage,
      selectedGenre: selectedGenre ?? this.selectedGenre,
      hasMorePages: hasMorePages ?? this.hasMorePages,
    );
  }
}

class VideoCatalogNotifier extends StateNotifier<VideoCatalogState> {
  VideoCatalogNotifier(this.ref) : super(const VideoCatalogState());

  final Ref ref;

  Future<void> loadCatalog({String? genre}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      final videosData = await apiService.getVideoCatalog(
        page: 1,
        limit: 20,
        genre: genre,
        includeReels: false,
      );

      final videos = (videosData as Iterable)
          .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        videos: videos,
        isLoading: false,
        currentPage: 1,
        selectedGenre: genre,
        hasMorePages: videos.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadMoreCatalog() async {
    if (state.isLoading || !state.hasMorePages) return;

    state = state.copyWith(isLoading: true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final nextPage = state.currentPage + 1;

      final videosData = await apiService.getVideoCatalog(
        page: nextPage,
        limit: 20,
        genre: state.selectedGenre,
        includeReels: false,
      );

      final newVideos = (videosData as Iterable)
          .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        videos: [...state.videos, ...newVideos],
        isLoading: false,
        currentPage: nextPage,
        hasMorePages: newVideos.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

// Video Catalog Provider
final videoCatalogProvider =
    StateNotifierProvider<VideoCatalogNotifier, VideoCatalogState>((ref) {
      return VideoCatalogNotifier(ref);
    });

// Single video provider
final videoDetailsProvider = FutureProvider.family<VideoModel?, String>((
  ref,
  videoId,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final videoData = await apiService.getVideoDetails(videoId);
    return VideoModel.fromJson(videoData as Map<String, dynamic>);
  } catch (e) {
    return null;
  }
});

// Search videos provider
final searchVideosProvider = FutureProvider.family<List<VideoModel>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];
  final apiService = ref.watch(apiServiceProvider);
  try {
    final videosData = await apiService.searchVideos(
      query: query,
      includeReels: false,
    );
    return (videosData as Iterable)
        .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (e) {
    return [];
  }
});

final reelsCatalogProvider = FutureProvider<List<VideoModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final videosData = await apiService.getVideoCatalog(
      page: 1,
      limit: 50,
      reelsOnly: true,
    );
    return (videosData as Iterable)
        .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (e) {
    return [];
  }
});
