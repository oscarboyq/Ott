import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/core/models/watchlist_item_model.dart';
import 'package:video/core/providers/service_providers.dart';

// Watchlist State
class WatchlistState {
  final List<WatchlistItemModel> items;
  final bool isLoading;
  final String? errorMessage;

  const WatchlistState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  WatchlistState copyWith({
    List<WatchlistItemModel>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return WatchlistState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class WatchlistNotifier extends StateNotifier<WatchlistState> {
  WatchlistNotifier(this.ref) : super(const WatchlistState());

  final Ref ref;

  Future<void> loadWatchlist() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      final watchlistData = await apiService.getWatchlist();

      final items = (watchlistData as Iterable)
          .map(
            (item) => WatchlistItemModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addToWatchlist(String videoId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.addToWatchlist(videoId);

      // Reload watchlist
      await loadWatchlist();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> removeFromWatchlist(String videoId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.removeFromWatchlist(videoId);

      // Remove from local state
      state = state.copyWith(
        items: state.items.where((item) => item.videoId != videoId).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  bool isInWatchlist(String videoId) {
    return state.items.any((item) => item.videoId == videoId);
  }
}

// Watchlist Provider
final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
      return WatchlistNotifier(ref);
    });

// Computed provider for checking if video is in watchlist
final isInWatchlistProvider = Provider.family<bool, String>((ref, videoId) {
  return ref
      .watch(watchlistProvider)
      .items
      .any((item) => item.videoId == videoId);
});
