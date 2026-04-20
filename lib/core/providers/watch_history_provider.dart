import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:video/core/constants/app_config.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/models/series_history_item_model.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/models/watch_history_item_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/service_providers.dart';

class WatchHistoryState {
  const WatchHistoryState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<WatchHistoryItemModel> items;
  final bool isLoading;
  final String? errorMessage;

  WatchHistoryState copyWith({
    List<WatchHistoryItemModel>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return WatchHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class WatchHistoryNotifier extends StateNotifier<WatchHistoryState> {
  WatchHistoryNotifier(this.ref) : super(const WatchHistoryState()) {
    // React to authentication changes so that history is always
    // consistent with the current user without relying on individual
    // pages calling loadHistory() at the right time.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        // User just logged out — wipe in-memory state and both local caches
        // so the next user (or the same user on re-login) starts clean.
        state = const WatchHistoryState();
        _clearAllLocalCaches();
      } else if (previous?.isAuthenticated != true && next.isAuthenticated) {
        // User just logged in — fetch the authoritative history from Supabase.
        loadHistory();
      }
    });
  }

  final Ref ref;
  final Uuid _uuid = const Uuid();

  /// Removes video and series history caches from SharedPreferences.
  Future<void> _clearAllLocalCaches() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(AppConstants.watchHistoryCacheKey),
      prefs.remove(AppConstants.seriesHistoryCacheKey),
    ]);
    // Force the series history FutureProvider to re-evaluate with the cleared cache.
    ref.invalidate(seriesHistoryProvider);
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final items = await _readHistoryItems();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> recordPlayback({
    required VideoModel video,
    required int watchedSeconds,
  }) async {
    final normalizedWatchedSeconds = _normalizeWatchedSeconds(
      watchedSeconds: watchedSeconds,
      totalDurationSeconds: video.duration,
    );
    final item = WatchHistoryItemModel(
      id: _uuid.v4(),
      videoId: video.id,
      watchedAt: DateTime.now(),
      durationWatchedSeconds: normalizedWatchedSeconds,
      video: video,
    );

    try {
      await _saveLocalHistoryItem(item);

      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        final apiService = ref.read(apiServiceProvider);
        await apiService.saveWatchHistory(
          videoId: video.id,
          durationWatchedSeconds: normalizedWatchedSeconds,
        );
      }

      state = state.copyWith(items: _mergeHistoryItem(state.items, item));
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> recordSeriesPlayback({
    required SeriesModel series,
    required SeriesEpisodeModel episode,
    required int watchedSeconds,
  }) async {
    final clampedWatchedSeconds = watchedSeconds.clamp(0, episode.duration);
    final isCompleted =
        episode.duration > 0 && clampedWatchedSeconds >= episode.duration - 5;
    final normalizedWatchedSeconds = isCompleted ? 0 : clampedWatchedSeconds;
    final authState = ref.read(authProvider);
    final item = SeriesHistoryItemModel(
      id: _uuid.v4(),
      userId: authState.user?.id ?? 'guest',
      seriesId: series.id,
      seasonId: episode.seasonId,
      episodeId: episode.id,
      positionSeconds: normalizedWatchedSeconds,
      isCompleted: isCompleted,
      lastWatchedAt: DateTime.now(),
      series: series,
      episode: episode,
    );

    try {
      await _saveLocalSeriesHistoryItem(item);

      if (authState.isAuthenticated) {
        final apiService = ref.read(apiServiceProvider);
        await apiService.saveSeriesProgress(
          seriesId: series.id,
          seasonId: episode.seasonId,
          episodeId: episode.id,
          positionSeconds: normalizedWatchedSeconds,
          isCompleted: isCompleted,
        );
      }

      ref.invalidate(seriesHistoryProvider);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  WatchHistoryItemModel? getItemForVideo(String videoId) {
    for (final item in state.items) {
      if (item.videoId == videoId) {
        return item;
      }
    }
    return null;
  }

  Future<List<WatchHistoryItemModel>> _readHistoryItems() async {
    final authState = ref.read(authProvider);
    final localItems = await _readLocalHistoryItems();
    if (authState.isAuthenticated) {
      try {
        final apiService = ref.read(apiServiceProvider);
        final historyData = await apiService.getWatchHistory();
        final remoteItems = (historyData as Iterable)
            .map(
              (item) => WatchHistoryItemModel.fromRemoteJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false);
        return _dedupeAndLimit([...remoteItems, ...localItems]);
      } catch (_) {
        return _dedupeAndLimit(localItems);
      }
    }

    return _dedupeAndLimit(localItems);
  }

  Future<void> _saveLocalHistoryItem(WatchHistoryItemModel item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _mergeHistoryItem(await _readLocalHistoryItems(), item);
    final encoded = jsonEncode(
      items.map((historyItem) => historyItem.toLocalJson()).toList(),
    );
    await prefs.setString(AppConstants.watchHistoryCacheKey, encoded);
  }

  Future<List<WatchHistoryItemModel>> _readLocalHistoryItems() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson =
        prefs.getString(AppConstants.watchHistoryCacheKey) ?? '[]';
    final decoded = jsonDecode(cachedJson) as List<dynamic>;
    return decoded
        .map(
          (item) => WatchHistoryItemModel.fromLocalJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _saveLocalSeriesHistoryItem(SeriesHistoryItemModel item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _mergeSeriesHistoryItem(
      await _readLocalSeriesHistoryItems(),
      item,
    );
    final encoded = jsonEncode(
      items.map((historyItem) => historyItem.toLocalJson()).toList(),
    );
    await prefs.setString(AppConstants.seriesHistoryCacheKey, encoded);
  }

  Future<List<SeriesHistoryItemModel>> _readLocalSeriesHistoryItems() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson =
        prefs.getString(AppConstants.seriesHistoryCacheKey) ?? '[]';
    final decoded = jsonDecode(cachedJson) as List<dynamic>;
    return decoded
        .map(
          (item) => SeriesHistoryItemModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  List<WatchHistoryItemModel> _mergeHistoryItem(
    List<WatchHistoryItemModel> items,
    WatchHistoryItemModel item,
  ) {
    final updated = <WatchHistoryItemModel>[item];
    updated.addAll(
      items.where((existingItem) => existingItem.videoId != item.videoId),
    );
    return _dedupeAndLimit(updated);
  }

  List<WatchHistoryItemModel> _dedupeAndLimit(
    List<WatchHistoryItemModel> items,
  ) {
    final latestByVideo = <String, WatchHistoryItemModel>{};

    for (final item
        in items..sort((a, b) => b.watchedAt.compareTo(a.watchedAt))) {
      latestByVideo.putIfAbsent(item.videoId, () => item);
    }

    final deduped = latestByVideo.values.toList(growable: false)
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));

    if (deduped.length <= AppConstants.maxWatchHistoryItems) {
      return deduped;
    }

    return deduped
        .take(AppConstants.maxWatchHistoryItems)
        .toList(growable: false);
  }

  List<SeriesHistoryItemModel> _mergeSeriesHistoryItem(
    List<SeriesHistoryItemModel> items,
    SeriesHistoryItemModel item,
  ) {
    final updated = <SeriesHistoryItemModel>[item];
    updated.addAll(
      items.where((existingItem) => existingItem.episodeId != item.episodeId),
    );
    return _dedupeAndLimitSeriesHistory(updated);
  }

  List<SeriesHistoryItemModel> _dedupeAndLimitSeriesHistory(
    List<SeriesHistoryItemModel> items,
  ) {
    final latestByEpisode = <String, SeriesHistoryItemModel>{};

    for (final item
        in items..sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt))) {
      latestByEpisode.putIfAbsent(item.episodeId, () => item);
    }

    final deduped = latestByEpisode.values.toList(growable: false)
      ..sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));

    if (deduped.length <= AppConstants.maxWatchHistoryItems) {
      return deduped;
    }

    return deduped
        .take(AppConstants.maxWatchHistoryItems)
        .toList(growable: false);
  }

  int _normalizeWatchedSeconds({
    required int watchedSeconds,
    required int totalDurationSeconds,
  }) {
    final clamped = watchedSeconds.clamp(0, totalDurationSeconds);
    if (totalDurationSeconds > 0 && clamped >= totalDurationSeconds - 5) {
      return 0;
    }
    return clamped;
  }
}

final watchHistoryProvider =
    StateNotifierProvider<WatchHistoryNotifier, WatchHistoryState>((ref) {
      return WatchHistoryNotifier(ref);
    });

final watchHistoryItemProvider =
    Provider.family<WatchHistoryItemModel?, String>((ref, videoId) {
      return ref
          .watch(watchHistoryProvider)
          .items
          .where((item) => item.videoId == videoId)
          .firstOrNull;
    });

final seriesHistoryProvider = FutureProvider<List<SeriesHistoryItemModel>>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  final cachedJson =
      prefs.getString(AppConstants.seriesHistoryCacheKey) ?? '[]';
  final decoded = jsonDecode(cachedJson) as List<dynamic>;
  final localItems =
      decoded
          .map(
            (item) => SeriesHistoryItemModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));

  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) {
    if (localItems.length <= AppConstants.maxWatchHistoryItems) {
      return localItems;
    }

    return localItems
        .take(AppConstants.maxWatchHistoryItems)
        .toList(growable: false);
  }

  try {
    final apiService = ref.watch(apiServiceProvider);
    final historyData = await apiService.getRecentSeriesHistory();
    final remoteItems = (historyData as Iterable)
        .map(
          (item) => SeriesHistoryItemModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    final latestByEpisode = <String, SeriesHistoryItemModel>{};
    for (final item in [
      ...remoteItems,
      ...localItems,
    ]..sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt))) {
      latestByEpisode.putIfAbsent(item.episodeId, () => item);
    }
    final items = latestByEpisode.values.toList(growable: false)
      ..sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    if (items.length <= AppConstants.maxWatchHistoryItems) {
      return items;
    }
    return items
        .take(AppConstants.maxWatchHistoryItems)
        .toList(growable: false);
  } catch (_) {
    if (localItems.length <= AppConstants.maxWatchHistoryItems) {
      return localItems;
    }
    return localItems
        .take(AppConstants.maxWatchHistoryItems)
        .toList(growable: false);
  }
});
