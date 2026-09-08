import 'dart:async';

import 'package:another_tus_client/another_tus_client.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/core/models/bunny_upload_session.dart';

enum MediaUploadStage { idle, uploading, paused, uploaded, cancelled, failed }

class MediaUploadState {
  const MediaUploadState({
    this.stage = MediaUploadStage.idle,
    this.progress = 0,
    this.estimatedRemaining,
    this.error,
  });

  final MediaUploadStage stage;
  final double progress;
  final Duration? estimatedRemaining;
  final String? error;

  bool get isActive =>
      stage == MediaUploadStage.uploading || stage == MediaUploadStage.paused;

  MediaUploadState copyWith({
    MediaUploadStage? stage,
    double? progress,
    Duration? estimatedRemaining,
    bool clearEstimate = false,
    String? error,
    bool clearError = false,
  }) {
    return MediaUploadState(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      estimatedRemaining: clearEstimate
          ? null
          : estimatedRemaining ?? this.estimatedRemaining,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class MediaUploadController extends StateNotifier<MediaUploadState> {
  MediaUploadController() : super(const MediaUploadState());

  TusClient? _client;
  Future<void> Function(Object error)? _onError;

  Future<void> start({
    required XFile file,
    required String title,
    required BunnyUploadSession session,
    required Future<void> Function() onComplete,
    required Future<void> Function(Object error) onError,
  }) async {
    if (state.isActive) return;

    final client = TusClient(
      file,
      store: TusMemoryStore(),
      maxChunkSize: 6 * 1024 * 1024,
      retries: 5,
      retryInterval: 2,
      retryScale: RetryScale.exponential,
    );
    _client = client;
    _onError = onError;
    state = const MediaUploadState(stage: MediaUploadStage.uploading);

    try {
      await client.upload(
        uri: Uri.parse(session.uploadUrl),
        headers: {
          'AuthorizationSignature': session.signature,
          'AuthorizationExpire': '${session.expirationTime}',
          'LibraryId': session.libraryId,
          'VideoId': session.videoId,
        },
        metadata: {
          'filetype': file.mimeType ?? _videoMimeType(file.name),
          'title': title,
        },
        preventDuplicates: true,
        onProgress: (progress, estimate) {
          if (state.stage == MediaUploadStage.uploading) {
            state = state.copyWith(
              progress: progress.clamp(0, 100),
              estimatedRemaining: estimate,
              clearError: true,
            );
          }
        },
        onComplete: () {
          state = state.copyWith(
            stage: MediaUploadStage.uploaded,
            progress: 100,
            clearEstimate: true,
            clearError: true,
          );
          unawaited(onComplete());
        },
      );
    } catch (error) {
      if (state.stage == MediaUploadStage.cancelled) return;
      state = state.copyWith(
        stage: MediaUploadStage.failed,
        error: error.toString(),
        clearEstimate: true,
      );
      await onError(error);
    }
  }

  Future<void> pause() async {
    final client = _client;
    if (client == null || state.stage != MediaUploadStage.uploading) return;
    await client.pauseUpload();
    state = state.copyWith(stage: MediaUploadStage.paused);
  }

  Future<void> resume() async {
    final client = _client;
    if (client == null || state.stage != MediaUploadStage.paused) return;
    state = state.copyWith(stage: MediaUploadStage.uploading, clearError: true);
    try {
      await client.resumeUpload();
    } catch (error) {
      state = state.copyWith(
        stage: MediaUploadStage.failed,
        error: error.toString(),
        clearEstimate: true,
      );
      await _onError?.call(error);
    }
  }

  Future<void> cancel() async {
    final client = _client;
    state = state.copyWith(
      stage: MediaUploadStage.cancelled,
      clearEstimate: true,
    );
    if (client != null) {
      await client.cancelUpload();
    }
  }

  static String _videoMimeType(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'mkv' => 'video/x-matroska',
      'avi' => 'video/x-msvideo',
      _ => 'video/mp4',
    };
  }
}

final mediaUploadControllerProvider =
    StateNotifierProvider.autoDispose<MediaUploadController, MediaUploadState>(
      (ref) => MediaUploadController(),
    );
