import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/service_providers.dart';
import 'package:video/core/providers/video_catalog_provider.dart';

class VideoRatingStats {
  const VideoRatingStats({required this.average, required this.count});

  final double average;
  final int count;
}

final currentUserVideoRatingProvider = FutureProvider.family<int?, String>((
  ref,
  videoId,
) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    return null;
  }

  final apiService = ref.watch(apiServiceProvider);
  return apiService.getCurrentUserVideoRating(videoId);
});

final videoRatingStatsProvider =
    FutureProvider.family<VideoRatingStats, String>((ref, videoId) async {
      final apiService = ref.watch(apiServiceProvider);
      final data = await apiService.getVideoRatingStats(videoId);
      return VideoRatingStats(
        average: (data['average'] as num?)?.toDouble() ?? 0,
        count: (data['count'] as num?)?.toInt() ?? 0,
      );
    });

class VideoRatingSubmissionNotifier extends StateNotifier<AsyncValue<void>> {
  VideoRatingSubmissionNotifier(this.ref, this.videoId)
    : super(const AsyncValue.data(null));

  final Ref ref;
  final String videoId;

  Future<void> submitRating(int rating) async {
    state = const AsyncValue.loading();
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.submitVideoRating(videoId: videoId, rating: rating);

      state = const AsyncValue.data(null);
      ref.invalidate(currentUserVideoRatingProvider(videoId));
      ref.invalidate(videoRatingStatsProvider(videoId));
      ref.invalidate(videoDetailsProvider(videoId));
      ref.invalidate(videoCatalogProvider);
      ref.invalidate(reelsCatalogProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final videoRatingSubmissionProvider =
    StateNotifierProvider.family<
      VideoRatingSubmissionNotifier,
      AsyncValue<void>,
      String
    >((ref, videoId) {
      return VideoRatingSubmissionNotifier(ref, videoId);
    });
