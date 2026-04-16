import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/core/models/video_model.dart';

// ─────────────────────────────────────────
// Admin State
// ─────────────────────────────────────────

class AdminState {
  final List<VideoModel> videos;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const AdminState({
    this.videos = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  AdminState copyWith({
    List<VideoModel>? videos,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return AdminState(
      videos: videos ?? this.videos,
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

  Future<void> _clearFeaturedVideos({String? exceptId}) async {
    var query = _db.from('videos').update({'is_featured': false});
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
    String? director,
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
        if (director != null && director.isNotEmpty)
          'director': director.trim(),
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
    String? director,
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
            if (director != null) 'director': director.trim(),
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
