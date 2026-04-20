import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/series_season_model.dart';
import 'package:video/core/models/series_watch_progress_model.dart';
import 'package:video/core/providers/service_providers.dart';

class SeriesCatalogState {
  const SeriesCatalogState({
    this.series = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<SeriesModel> series;
  final bool isLoading;
  final String? errorMessage;

  SeriesCatalogState copyWith({
    List<SeriesModel>? series,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SeriesCatalogState(
      series: series ?? this.series,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SeriesCatalogNotifier extends StateNotifier<SeriesCatalogState> {
  SeriesCatalogNotifier(this.ref) : super(const SeriesCatalogState());

  final Ref ref;

  Future<void> loadSeriesCatalog({String? genre}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      final seriesData = await apiService.getSeriesCatalog(genre: genre);
      final series = (seriesData as Iterable)
          .map((item) => SeriesModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);

      state = state.copyWith(series: series, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final seriesCatalogProvider =
    StateNotifierProvider<SeriesCatalogNotifier, SeriesCatalogState>((ref) {
      return SeriesCatalogNotifier(ref);
    });

final seriesDetailsProvider = FutureProvider.family<SeriesModel?, String>((
  ref,
  seriesId,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final data = await apiService.getSeriesDetails(seriesId);
    if (data == null) {
      return null;
    }

    return SeriesModel.fromJson(data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

final seriesSeasonsProvider =
    FutureProvider.family<List<SeriesSeasonModel>, String>((
      ref,
      seriesId,
    ) async {
      final apiService = ref.watch(apiServiceProvider);
      try {
        final data = await apiService.getSeriesSeasons(seriesId);
        return (data as Iterable)
            .map(
              (item) =>
                  SeriesSeasonModel.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false);
      } catch (_) {
        return const [];
      }
    });

final seasonEpisodesProvider =
    FutureProvider.family<List<SeriesEpisodeModel>, String>((
      ref,
      seasonId,
    ) async {
      final apiService = ref.watch(apiServiceProvider);
      try {
        final data = await apiService.getSeasonEpisodes(seasonId);
        return (data as Iterable)
            .map(
              (item) =>
                  SeriesEpisodeModel.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false);
      } catch (_) {
        return const [];
      }
    });

final seriesEpisodeDetailsProvider =
    FutureProvider.family<SeriesEpisodeModel?, String>((ref, episodeId) async {
      final apiService = ref.watch(apiServiceProvider);
      try {
        final data = await apiService.getSeriesEpisodeDetails(episodeId);
        if (data == null) {
          return null;
        }

        return SeriesEpisodeModel.fromJson(data as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    });

final seriesProgressProvider =
    FutureProvider.family<SeriesWatchProgressModel?, String>((
      ref,
      seriesId,
    ) async {
      final apiService = ref.watch(apiServiceProvider);
      try {
        final data = await apiService.getSeriesProgress(seriesId);
        if (data == null) {
          return null;
        }

        return SeriesWatchProgressModel.fromJson(data as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    });
