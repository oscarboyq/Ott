import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/series_season_model.dart';
import 'package:video/core/models/subscription_plan_model.dart';
import 'package:video/core/models/video_model.dart';

// ─────────────────────────────────────────
// Admin State
// ─────────────────────────────────────────

class AdminState {
  final List<VideoModel> videos;
  final List<SeriesModel> series;
  final List<SubscriptionPlanModel> subscriptionPlans;
  final String? seriesStatusMessage;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const AdminState({
    this.videos = const [],
    this.series = const [],
    this.subscriptionPlans = const [],
    this.seriesStatusMessage,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  AdminState copyWith({
    List<VideoModel>? videos,
    List<SeriesModel>? series,
    List<SubscriptionPlanModel>? subscriptionPlans,
    String? seriesStatusMessage,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return AdminState(
      videos: videos ?? this.videos,
      series: series ?? this.series,
      subscriptionPlans: subscriptionPlans ?? this.subscriptionPlans,
      seriesStatusMessage: seriesStatusMessage,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

// ─────────────────────────────────────────
// Admin Notifier
// ─────────────────────────────────────────

class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier() : super(const AdminState());

  static const String _seriesSchemaMissingMessage =
      'TV series tables are not available yet. Run the latest Supabase migrations to enable series management.';
  static const String _seriesWriteDeniedMessage =
      'Series update was not applied. Check the series admin RLS policies and try again.';
  static const String _subscriptionPlanWriteDeniedMessage =
      'Subscription plan update was not applied. Check the subscription plan admin RLS policies and applied migrations.';
  static const String _subscriptionPlanWriteMismatchMessage =
      'Subscription plan update completed, but the returned data did not match the submitted values.';

  SupabaseClient get _db => Supabase.instance.client;

  String _formatError(Object error) {
    if (error is StorageException) {
      return 'StorageException: ${error.message}';
    }
    if (error is PostgrestException) {
      return 'PostgrestException: ${error.message}';
    }
    if (error is AuthException) {
      return 'AuthException: ${error.message}';
    }
    return '${error.runtimeType}: $error';
  }

  void _logError(String action, Object error, StackTrace stackTrace) {
    debugPrint('[AdminNotifier] $action failed: ${_formatError(error)}');
    debugPrintStack(stackTrace: stackTrace);
  }

  bool _isSeriesSchemaMissing(Object error) {
    if (error is! PostgrestException) {
      return false;
    }

    final message = error.message.toLowerCase();
    return message.contains('schema cache') &&
        (message.contains("public.series") ||
            message.contains("public.series_seasons") ||
            message.contains("public.series_episodes") ||
            message.contains("public.series_watch_progress"));
  }

  Never _throwSeriesWriteDenied() {
    throw StateError(_seriesWriteDeniedMessage);
  }

  Never _throwSubscriptionPlanWriteDenied() {
    throw StateError(_subscriptionPlanWriteDeniedMessage);
  }

  Future<void> _clearFeaturedVideos({String? exceptId}) async {
    var query = _db.from('videos').update({'is_featured': false});
    if (exceptId != null) {
      await query.neq('id', exceptId).eq('is_featured', true);
      return;
    }
    await query.eq('is_featured', true);
  }

  Future<void> _clearFeaturedSeries({String? exceptId}) async {
    var query = _db.from('series').update({'is_featured': false});
    if (exceptId != null) {
      await query.neq('id', exceptId).eq('is_featured', true);
      return;
    }
    await query.eq('is_featured', true);
  }

  void _updateVideoInState(String id, VideoModel Function(VideoModel) updater) {
    state = state.copyWith(
      videos: state.videos
          .map((video) => video.id == id ? updater(video) : video)
          .toList(growable: false),
    );
  }

  void _setOnlyFeaturedInState(String id) {
    state = state.copyWith(
      videos: state.videos
          .map((video) => video.copyWith(isFeatured: video.id == id))
          .toList(growable: false),
    );
  }

  Future<void> loadVideos() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _db
          .from('videos')
          .select()
          .order('created_at', ascending: false);

      final videos = (data as List)
          .map((e) => VideoModel.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(isLoading: false, videos: videos);
    } catch (error, stackTrace) {
      _logError('loadVideos', error, stackTrace);
      state = state.copyWith(isLoading: false, error: _formatError(error));
    }
  }

  Future<void> loadSeries() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      seriesStatusMessage: null,
    );
    try {
      final data = await _db
          .from('series')
          .select('*, series_seasons(id), series_episodes(id)')
          .order('created_at', ascending: false);

      final series = (data as List)
          .map(
            (e) => SeriesModel.fromJson(
              _withSeriesCounts(Map<String, dynamic>.from(e as Map)),
            ),
          )
          .toList(growable: false);

      state = state.copyWith(
        isLoading: false,
        series: series,
        seriesStatusMessage: null,
      );
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          isLoading: false,
          series: const [],
          error: null,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return;
      }

      _logError('loadSeries', error, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: _formatError(error),
        seriesStatusMessage: null,
      );
    }
  }

  Future<void> loadSubscriptionPlans() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _db
          .from('subscription_plans')
          .select()
          .order('is_active', ascending: false)
          .order('monthly_price', ascending: true)
          .order('name', ascending: true);

      final plans = (data as List)
          .map(
            (item) => SubscriptionPlanModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);

      state = state.copyWith(isLoading: false, subscriptionPlans: plans);
    } catch (error, stackTrace) {
      _logError('loadSubscriptionPlans', error, stackTrace);
      state = state.copyWith(isLoading: false, error: _formatError(error));
    }
  }

  Future<bool> updateSubscriptionPlan({
    required String id,
    required String name,
    required String description,
    required double monthlyPrice,
    required double yearlyPrice,
    required List<String> features,
    required bool isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final normalizedName = name.trim();
      final normalizedDescription = description.trim();
      final normalizedFeatures = features
          .map((feature) => feature.trim())
          .where((feature) => feature.isNotEmpty)
          .toList(growable: false);

      final existingPlan = await _db
          .from('subscription_plans')
          .select('id')
          .eq('id', id)
          .maybeSingle();

      if (existingPlan == null) {
        throw StateError('Subscription plan not found.');
      }

      final updatedRows = await _db
          .from('subscription_plans')
          .update({
            'name': normalizedName,
            'description': normalizedDescription,
            'monthly_price': monthlyPrice,
            'annual_price': yearlyPrice,
            'features': {'key_features': normalizedFeatures},
            'is_active': isActive,
          })
          .eq('id', id)
          .select();

      if ((updatedRows as List).isEmpty) {
        _throwSubscriptionPlanWriteDenied();
      }

      final refreshedPlan = SubscriptionPlanModel.fromJson(
        Map<String, dynamic>.from(updatedRows.first as Map),
      );

      final updateApplied =
          refreshedPlan.name == normalizedName &&
          refreshedPlan.description == normalizedDescription &&
          refreshedPlan.monthlyPrice == monthlyPrice &&
          refreshedPlan.yearlyPrice == yearlyPrice &&
          refreshedPlan.isActive == isActive &&
          listEquals(refreshedPlan.features, normalizedFeatures);

      if (!updateApplied) {
        throw StateError(_subscriptionPlanWriteMismatchMessage);
      }

      await loadSubscriptionPlans();

      state = state.copyWith(successMessage: 'Subscription plan updated');
      return true;
    } catch (error, stackTrace) {
      _logError('updateSubscriptionPlan', error, stackTrace);
      state = state.copyWith(isLoading: false, error: _formatError(error));
      return false;
    }
  }

  Future<bool> addVideo({
    required String title,
    required String description,
    required String thumbnailUrl,
    required String videoUrl,
    required String genre,
    required int durationSeconds,
    required bool isFree,
    required bool isReel,
    required bool isFeatured,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isFeatured) {
        await _clearFeaturedVideos();
      }

      await _db.from('videos').insert({
        'title': title.trim(),
        'description': description.trim(),
        'thumbnail_url': thumbnailUrl.trim(),
        'video_url': videoUrl.trim(),
        'category': genre.trim(),
        if (durationSeconds > 0) 'duration_seconds': durationSeconds,
        'is_free': isFree,
        'is_reel': isReel,
        'is_featured': isFeatured,
        'rating': 0.0,
        'views_count': 0,
        'release_date': DateTime.now().toIso8601String().substring(0, 10),
      });
      await loadVideos();
      state = state.copyWith(successMessage: 'Video added successfully');
      return true;
    } catch (error, stackTrace) {
      _logError('addVideo', error, stackTrace);
      state = state.copyWith(isLoading: false, error: _formatError(error));
      return false;
    }
  }

  Future<bool> updateVideo({
    required String id,
    required String title,
    required String description,
    required String thumbnailUrl,
    required String videoUrl,
    required String genre,
    required int durationSeconds,
    required bool isFree,
    required bool isReel,
    required bool isFeatured,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isFeatured) {
        await _clearFeaturedVideos(exceptId: id);
      }

      await _db
          .from('videos')
          .update({
            'title': title.trim(),
            'description': description.trim(),
            'thumbnail_url': thumbnailUrl.trim(),
            'video_url': videoUrl.trim(),
            'category': genre.trim(),
            if (durationSeconds > 0) 'duration_seconds': durationSeconds,
            'is_free': isFree,
            'is_reel': isReel,
            'is_featured': isFeatured,
          })
          .eq('id', id);
      await loadVideos();
      state = state.copyWith(successMessage: 'Video updated successfully');
      return true;
    } catch (error, stackTrace) {
      _logError('updateVideo', error, stackTrace);
      state = state.copyWith(isLoading: false, error: _formatError(error));
      return false;
    }
  }

  Future<bool> deleteVideo(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.from('videos').delete().eq('id', id);
      await loadVideos();
      state = state.copyWith(successMessage: 'Video deleted');
      return true;
    } catch (error, stackTrace) {
      _logError('deleteVideo', error, stackTrace);
      state = state.copyWith(isLoading: false, error: _formatError(error));
      return false;
    }
  }

  Future<bool> addSeries({
    required String title,
    required String description,
    required String posterUrl,
    required String backdropUrl,
    required String trailerUrl,
    required String genre,
    required String tagline,
    required String releaseDate,
    required bool isFree,
    required bool isFeatured,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isFeatured) {
        await _clearFeaturedSeries();
      }

      final inserted = await _db
          .from('series')
          .insert({
            'title': title.trim(),
            'slug': _slugify(title),
            'description': description.trim(),
            'poster_url': posterUrl.trim(),
            'backdrop_url': backdropUrl.trim(),
            'trailer_url': trailerUrl.trim(),
            'category': genre.trim(),
            'tagline': tagline.trim(),
            'release_date': releaseDate.trim(),
            'is_free': isFree,
            'is_featured': isFeatured,
            'is_published': true,
          })
          .select('id')
          .maybeSingle();

      if (inserted == null) {
        _throwSeriesWriteDenied();
      }

      await loadSeries();
      state = state.copyWith(successMessage: 'Series added successfully');
      return true;
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          isLoading: false,
          error: _seriesSchemaMissingMessage,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return false;
      }

      _logError('addSeries', error, stackTrace);
      state = state.copyWith(isLoading: false, error: _formatError(error));
      return false;
    }
  }

  Future<bool> updateSeries({
    required String id,
    required String title,
    required String description,
    required String posterUrl,
    required String backdropUrl,
    required String trailerUrl,
    required String genre,
    required String tagline,
    required String releaseDate,
    required bool isFree,
    required bool isFeatured,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isFeatured) {
        await _clearFeaturedSeries(exceptId: id);
      }

      final updated = await _db
          .from('series')
          .update({
            'title': title.trim(),
            'slug': _slugify(title),
            'description': description.trim(),
            'poster_url': posterUrl.trim(),
            'backdrop_url': backdropUrl.trim(),
            'trailer_url': trailerUrl.trim(),
            'category': genre.trim(),
            'tagline': tagline.trim(),
            'release_date': releaseDate.trim(),
            'is_free': isFree,
            'is_featured': isFeatured,
          })
          .eq('id', id)
          .select('id')
          .maybeSingle();

      if (updated == null) {
        _throwSeriesWriteDenied();
      }

      await loadSeries();
      state = state.copyWith(successMessage: 'Series updated successfully');
      return true;
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          isLoading: false,
          error: _seriesSchemaMissingMessage,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return false;
      }

      _logError('updateSeries', error, stackTrace);
      state = state.copyWith(isLoading: false, error: _formatError(error));
      return false;
    }
  }

  Future<bool> deleteSeries(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final deleted = await _db
          .from('series')
          .delete()
          .eq('id', id)
          .select('id')
          .maybeSingle();

      if (deleted == null) {
        _throwSeriesWriteDenied();
      }

      await loadSeries();
      state = state.copyWith(successMessage: 'Series deleted');
      return true;
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          isLoading: false,
          error: _seriesSchemaMissingMessage,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return false;
      }

      _logError('deleteSeries', error, stackTrace);
      state = state.copyWith(isLoading: false, error: _formatError(error));
      return false;
    }
  }

  Future<List<SeriesSeasonModel>> loadSeriesSeasons(String seriesId) async {
    try {
      final data = await _db
          .from('series_seasons')
          .select('*, series_episodes(id)')
          .eq('series_id', seriesId)
          .order('season_number', ascending: true);

      return (data as List)
          .map(
            (e) => SeriesSeasonModel.fromJson(
              _withSeasonEpisodeCount(Map<String, dynamic>.from(e as Map)),
            ),
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          error: null,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return const [];
      }

      _logError('loadSeriesSeasons', error, stackTrace);
      state = state.copyWith(error: _formatError(error));
      return const [];
    }
  }

  Future<bool> addSeason({
    required String seriesId,
    required int seasonNumber,
    required String title,
    required String description,
    required String posterUrl,
    required String releaseDate,
  }) async {
    try {
      final inserted = await _db
          .from('series_seasons')
          .insert({
            'series_id': seriesId,
            'season_number': seasonNumber,
            'title': title.trim(),
            'description': description.trim(),
            'poster_url': posterUrl.trim(),
            'release_date': releaseDate.trim(),
          })
          .select('id')
          .maybeSingle();

      if (inserted == null) {
        _throwSeriesWriteDenied();
      }

      await loadSeries();
      state = state.copyWith(successMessage: 'Season added successfully');
      return true;
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          error: _seriesSchemaMissingMessage,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return false;
      }

      _logError('addSeason', error, stackTrace);
      state = state.copyWith(error: _formatError(error));
      return false;
    }
  }

  Future<bool> updateSeason({
    required String id,
    required int seasonNumber,
    required String title,
    required String description,
    required String posterUrl,
    required String releaseDate,
  }) async {
    try {
      final updated = await _db
          .from('series_seasons')
          .update({
            'season_number': seasonNumber,
            'title': title.trim(),
            'description': description.trim(),
            'poster_url': posterUrl.trim(),
            'release_date': releaseDate.trim(),
          })
          .eq('id', id)
          .select('id')
          .maybeSingle();

      if (updated == null) {
        _throwSeriesWriteDenied();
      }

      await loadSeries();
      state = state.copyWith(successMessage: 'Season updated successfully');
      return true;
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          error: _seriesSchemaMissingMessage,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return false;
      }

      _logError('updateSeason', error, stackTrace);
      state = state.copyWith(error: _formatError(error));
      return false;
    }
  }

  Future<bool> deleteSeason(String id) async {
    try {
      final deleted = await _db
          .from('series_seasons')
          .delete()
          .eq('id', id)
          .select('id')
          .maybeSingle();

      if (deleted == null) {
        _throwSeriesWriteDenied();
      }

      await loadSeries();
      state = state.copyWith(successMessage: 'Season deleted');
      return true;
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          error: _seriesSchemaMissingMessage,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return false;
      }

      _logError('deleteSeason', error, stackTrace);
      state = state.copyWith(error: _formatError(error));
      return false;
    }
  }

  Future<List<SeriesEpisodeModel>> loadSeasonEpisodes(String seasonId) async {
    try {
      final data = await _db
          .from('series_episodes')
          .select()
          .eq('season_id', seasonId)
          .order('episode_number', ascending: true);

      return (data as List)
          .map(
            (e) => SeriesEpisodeModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          error: null,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return const [];
      }

      _logError('loadSeasonEpisodes', error, stackTrace);
      state = state.copyWith(error: _formatError(error));
      return const [];
    }
  }

  Future<bool> addEpisode({
    required String seriesId,
    required String seasonId,
    required int episodeNumber,
    required String title,
    required String description,
    required String thumbnailUrl,
    required String videoUrl,
    required int durationSeconds,
    required bool isFree,
    required String releaseDate,
  }) async {
    try {
      final inserted = await _db
          .from('series_episodes')
          .insert({
            'series_id': seriesId,
            'season_id': seasonId,
            'episode_number': episodeNumber,
            'title': title.trim(),
            'description': description.trim(),
            'thumbnail_url': thumbnailUrl.trim(),
            'video_url': videoUrl.trim(),
            'duration_seconds': durationSeconds,
            'is_free': isFree,
            'release_date': releaseDate.trim(),
          })
          .select('id')
          .maybeSingle();

      if (inserted == null) {
        _throwSeriesWriteDenied();
      }

      await loadSeries();
      state = state.copyWith(successMessage: 'Episode added successfully');
      return true;
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          error: _seriesSchemaMissingMessage,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return false;
      }

      _logError('addEpisode', error, stackTrace);
      state = state.copyWith(error: _formatError(error));
      return false;
    }
  }

  Future<bool> updateEpisode({
    required String id,
    required int episodeNumber,
    required String title,
    required String description,
    required String thumbnailUrl,
    required String videoUrl,
    required int durationSeconds,
    required bool isFree,
    required String releaseDate,
  }) async {
    try {
      final updated = await _db
          .from('series_episodes')
          .update({
            'episode_number': episodeNumber,
            'title': title.trim(),
            'description': description.trim(),
            'thumbnail_url': thumbnailUrl.trim(),
            'video_url': videoUrl.trim(),
            'duration_seconds': durationSeconds,
            'is_free': isFree,
            'release_date': releaseDate.trim(),
          })
          .eq('id', id)
          .select('id')
          .maybeSingle();

      if (updated == null) {
        _throwSeriesWriteDenied();
      }

      await loadSeries();
      state = state.copyWith(successMessage: 'Episode updated successfully');
      return true;
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          error: _seriesSchemaMissingMessage,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return false;
      }

      _logError('updateEpisode', error, stackTrace);
      state = state.copyWith(error: _formatError(error));
      return false;
    }
  }

  Future<bool> deleteEpisode(String id) async {
    try {
      final deleted = await _db
          .from('series_episodes')
          .delete()
          .eq('id', id)
          .select('id')
          .maybeSingle();

      if (deleted == null) {
        _throwSeriesWriteDenied();
      }

      await loadSeries();
      state = state.copyWith(successMessage: 'Episode deleted');
      return true;
    } catch (error, stackTrace) {
      if (_isSeriesSchemaMissing(error)) {
        state = state.copyWith(
          error: _seriesSchemaMissingMessage,
          seriesStatusMessage: _seriesSchemaMissingMessage,
        );
        return false;
      }

      _logError('deleteEpisode', error, stackTrace);
      state = state.copyWith(error: _formatError(error));
      return false;
    }
  }

  Future<void> toggleFeatured(String id, {required bool isFeatured}) async {
    final previousVideos = state.videos;

    if (isFeatured) {
      _setOnlyFeaturedInState(id);
    } else {
      _updateVideoInState(id, (video) => video.copyWith(isFeatured: false));
    }

    try {
      if (isFeatured) {
        await _clearFeaturedVideos(exceptId: id);
      }
      await _db.from('videos').update({'is_featured': isFeatured}).eq('id', id);
    } catch (error, stackTrace) {
      _logError('toggleFeatured', error, stackTrace);
      state = state.copyWith(
        videos: previousVideos,
        error: _formatError(error),
      );
    }
  }

  Future<void> toggleFree(String id, {required bool isFree}) async {
    final previousVideos = state.videos;
    _updateVideoInState(
      id,
      (video) => video.copyWith(requiresPremium: !isFree),
    );

    try {
      await _db.from('videos').update({'is_free': isFree}).eq('id', id);
    } catch (error, stackTrace) {
      _logError('toggleFree', error, stackTrace);
      state = state.copyWith(
        videos: previousVideos,
        error: _formatError(error),
      );
    }
  }

  Map<String, dynamic> _withSeriesCounts(Map<String, dynamic> item) {
    final seasons = item['series_seasons'] as List<dynamic>? ?? const [];
    final episodes = item['series_episodes'] as List<dynamic>? ?? const [];

    return {
      ...item,
      'season_count': seasons.length,
      'episode_count': episodes.length,
    };
  }

  Map<String, dynamic> _withSeasonEpisodeCount(Map<String, dynamic> item) {
    final episodes = item['series_episodes'] as List<dynamic>? ?? const [];
    return {...item, 'episode_count': episodes.length};
  }

  String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  void clearFeedback() {
    state = state.copyWith(error: null, successMessage: null);
  }

  // ── Users ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadUsers() async {
    try {
      final data = await _db
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (error, stackTrace) {
      _logError('loadUsers', error, stackTrace);
      return [];
    }
  }

  Future<bool> setUserAdmin(String userId, {required bool isAdmin}) async {
    try {
      await _db
          .from('user_profiles')
          .update({'is_admin': isAdmin})
          .eq('id', userId);
      return true;
    } catch (error, stackTrace) {
      _logError('setUserAdmin', error, stackTrace);
      return false;
    }
  }
}

// ─────────────────────────────────────────
// Provider
// ─────────────────────────────────────────

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>(
  (_) => AdminNotifier(),
);
