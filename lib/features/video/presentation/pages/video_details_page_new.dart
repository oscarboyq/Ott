import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:video/app/theme/app_theme.dart';
import 'package:video/common/widgets/common_widgets.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/video_catalog_provider.dart';
import 'package:video/core/providers/watch_history_provider.dart';
import 'package:video/core/providers/video_rating_provider.dart';
import 'package:video/core/providers/watchlist_provider.dart';
import 'package:video/core/services/app_settings_service.dart';
import 'package:video/core/utils/playback_source_resolver.dart';
import 'package:video/features/video/presentation/widgets/bunny_web_player.dart';

class VideoDetailsPage extends ConsumerStatefulWidget {
  const VideoDetailsPage({
    required this.videoId,
    this.autoPlay = false,
    this.initialPositionSeconds,
    super.key,
  });

  final String videoId;
  final bool autoPlay;
  final int? initialPositionSeconds;

  @override
  ConsumerState<VideoDetailsPage> createState() => _VideoDetailsPageState();
}

class _VideoDetailsPageState extends ConsumerState<VideoDetailsPage> {
  VideoPlayerController? _videoPlayerController;
  bool _isPlaying = false;
  String? _initializedVideoUrl;
  int _selectedRating = 0;
  bool _showRatingPicker = false;
  String? _selectedQuality;
  VideoModel? _activeVideo;
  String? _resumeAppliedVideoId;
  int _lastPersistedPositionSeconds = -1;
  String? _autoPlayedVideoId;
  String? _seededHistoryVideoId;

  static const double _wideLayoutBreakpoint = 1100;

  bool _canWatchVideo({
    required bool isPremiumVideo,
    required bool isPremiumUser,
  }) {
    if (!isPremiumVideo) {
      return true;
    }

    return isPremiumUser;
  }

  bool _canRateVideo({
    required bool isAuthenticated,
    required bool isPremiumVideo,
    required bool isPremiumUser,
  }) {
    if (!isAuthenticated) {
      return false;
    }

    if (!isPremiumVideo) {
      return true;
    }

    return isPremiumUser;
  }

  String _ratingAccessLabel({
    required bool isAuthenticated,
    required bool isPremiumVideo,
    required bool canRate,
  }) {
    if (canRate) {
      return 'Rating access available';
    }

    if (!isAuthenticated) {
      return 'Sign in required to rate';
    }

    if (isPremiumVideo) {
      return 'Premium required to rate';
    }

    return 'Rating unavailable';
  }

  String _ratingCountLabel(int count) {
    if (count == 1) {
      return '1 rating';
    }

    return '$count ratings';
  }

  WatchHistoryNotifier? _watchHistoryNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchHistoryProvider.notifier).loadHistory();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchHistoryNotifier = ref.read(watchHistoryProvider.notifier);
  }

  @override
  void deactivate() {
    // Capture state synchronously while still valid, then defer the provider
    // call via Future() so it runs after the current frame — Riverpod forbids
    // modifying providers during lifecycle callbacks like deactivate().
    final video = _activeVideo;
    final notifier = _watchHistoryNotifier;
    final controller = _videoPlayerController;
    final seconds = (controller != null && controller.value.isInitialized)
        ? controller.value.position.inSeconds
        : _lastPersistedPositionSeconds;
    if (video != null && notifier != null && seconds > 0) {
      Future(() => notifier.recordPlayback(
            video: video,
            watchedSeconds: seconds,
          ));
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_handleVideoPlayerChanged);
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VideoDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _selectedRating = 0;
      _showRatingPicker = false;
      _selectedQuality = null;
      _seededHistoryVideoId = null;
    }
  }

  void _initializeVideoPlayer(VideoModel video) {
    if (_initializedVideoUrl == video.videoUrl &&
        _videoPlayerController != null) {
      _activeVideo = video;
      return;
    }

    _persistCurrentPlaybackPosition(force: true);
    _videoPlayerController?.removeListener(_handleVideoPlayerChanged);
    _videoPlayerController?.dispose();
    _initializedVideoUrl = video.videoUrl;
    _activeVideo = video;
    _resumeAppliedVideoId = null;
    _lastPersistedPositionSeconds = -1;
    _autoPlayedVideoId = null;

    final resolvedVideoUrl = resolvePlayableVideoUrl(video.videoUrl);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(resolvedVideoUrl),
    );
    _videoPlayerController = controller;
    controller.addListener(_handleVideoPlayerChanged);

    controller
        .initialize()
        .then((_) async {
          if (widget.initialPositionSeconds != null &&
              widget.initialPositionSeconds! > 0) {
            _maybeApplyResumePosition(
              video: video,
              controller: controller,
              resumeSeconds: widget.initialPositionSeconds!,
            );
          }

          if (widget.autoPlay && _autoPlayedVideoId != video.id) {
            _autoPlayedVideoId = video.id;
            await controller.play();
          }

          if (mounted) {
            setState(() {});
          }
        })
        .catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading video: $error'),
                duration: const Duration(seconds: 6),
              ),
            );
          }
        });
  }

  void _handleVideoPlayerChanged() {
    final controller = _videoPlayerController;
    final video = _activeVideo;
    if (controller == null || video == null) {
      return;
    }

    final value = controller.value;
    if (!value.isInitialized) {
      return;
    }

    if (_isPlaying != value.isPlaying && mounted) {
      setState(() {
        _isPlaying = value.isPlaying;
      });
    }

    final positionSeconds = value.position.inSeconds;
    if (!value.isPlaying) {
      _saveHistoryPosition(
        video: video,
        watchedSeconds: positionSeconds,
        force: true,
      );
      return;
    }

    _saveHistoryPosition(video: video, watchedSeconds: positionSeconds);
  }

  void _ensureHistorySeeded(VideoModel video, int resumeSeconds) {
    if (_seededHistoryVideoId == video.id) return;
    _seededHistoryVideoId = video.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = _watchHistoryNotifier ??
          (mounted ? ref.read(watchHistoryProvider.notifier) : null);
      if (notifier != null) {
        unawaited(
          notifier.recordPlayback(
            video: video,
            watchedSeconds: resumeSeconds,
          ),
        );
      }
    });
  }

  void _persistCurrentPlaybackPosition({bool force = false}) {
    final video = _activeVideo;
    if (video == null) return;

    final controller = _videoPlayerController;
    if (controller != null && controller.value.isInitialized) {
      _saveHistoryPosition(
        video: video,
        watchedSeconds: controller.value.position.inSeconds,
        force: force,
      );
    } else if (_lastPersistedPositionSeconds >= 0) {
      _saveHistoryPosition(
        video: video,
        watchedSeconds: _lastPersistedPositionSeconds,
        force: force,
      );
    }
  }

  void _saveHistoryPosition({
    required VideoModel video,
    required int watchedSeconds,
    bool force = false,
  }) {
    if (!force && _lastPersistedPositionSeconds >= 0) {
      final delta = (watchedSeconds - _lastPersistedPositionSeconds).abs();
      if (delta < 5) {
        return;
      }
    }

    _lastPersistedPositionSeconds = watchedSeconds;
    // Use only the cached notifier — never access ref directly here,
    // as this method may be called from deactivate().
    final notifier = _watchHistoryNotifier;
    if (notifier != null) {
      unawaited(
        notifier.recordPlayback(
          video: video,
          watchedSeconds: watchedSeconds,
        ),
      );
    }
  }

  void _maybeApplyResumePosition({
    required VideoModel video,
    required VideoPlayerController controller,
    required int resumeSeconds,
  }) {
    if (_resumeAppliedVideoId == video.id || resumeSeconds <= 0) {
      return;
    }

    final totalDurationSeconds = controller.value.duration.inSeconds;
    if (totalDurationSeconds <= 1) {
      return;
    }

    final seekSeconds = resumeSeconds.clamp(0, totalDurationSeconds - 1);
    if (seekSeconds <= 0) {
      _resumeAppliedVideoId = video.id;
      return;
    }

    _resumeAppliedVideoId = video.id;
    _lastPersistedPositionSeconds = seekSeconds;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _videoPlayerController != controller) {
        return;
      }

      unawaited(controller.seekTo(Duration(seconds: seekSeconds)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));
    final authState = ref.watch(authProvider);
    final historyItem = ref.watch(watchHistoryItemProvider(widget.videoId));
    final isInWatchlist = ref.watch(isInWatchlistProvider(widget.videoId));
    final currentUserRatingAsync = ref.watch(
      currentUserVideoRatingProvider(widget.videoId),
    );
    final videoRatingStatsAsync = ref.watch(
      videoRatingStatsProvider(widget.videoId),
    );
    final ratingSubmissionState = ref.watch(
      videoRatingSubmissionProvider(widget.videoId),
    );

    ref.listen<AsyncValue<void>>(
      videoRatingSubmissionProvider(widget.videoId),
      (previous, next) {
        next.whenOrNull(
          data: (_) {
            if (previous?.isLoading == true) {
              setState(() {
                _showRatingPicker = false;
                _selectedRating = 0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Your rating was saved.')),
              );
            }
          },
          error: (error, _) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.toString())));
          },
        );
      },
    );

    return videoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const LoadingIndicator(message: 'Loading video details...'),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: AppErrorWidget(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(videoDetailsProvider);
          },
        ),
      ),
      data: (video) {
        if (video == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppEmptyStateWidget(
              icon: Icons.videocam_off,
              title: 'Video Not Found',
              message: 'This video is no longer available',
            ),
          );
        }

        final isAuthenticated = authState.isAuthenticated;
        final hasPremiumAccess = authState.user?.isPremium == true;
        final canWatch = _canWatchVideo(
          isPremiumVideo: video.requiresPremium,
          isPremiumUser: hasPremiumAccess,
        );
        final canRate = _canRateVideo(
          isAuthenticated: isAuthenticated,
          isPremiumVideo: video.requiresPremium,
          isPremiumUser: hasPremiumAccess,
        );
        final ratingStats = videoRatingStatsAsync.valueOrNull;
        final currentUserRating = currentUserRatingAsync.valueOrNull;
        final isSubmittingRating = ratingSubmissionState.isLoading;
        final averageRating = ratingStats?.average ?? video.rating;
        final totalRatings = ratingStats?.count ?? video.ratingCount;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: const Text('Video Details'),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWideLayout =
                  constraints.maxWidth >= _wideLayoutBreakpoint;
              final sidePanel = _buildSidePanel(
                context: context,
                videoId: video.id,
                isAuthenticated: isAuthenticated,
                videoRequiresPremium: video.requiresPremium,
                canRate: canRate,
                currentUserRating: currentUserRating,
                isSubmittingRating: isSubmittingRating,
                isInWatchlist: isInWatchlist,
              );

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  AspectRatio(
                    aspectRatio: isWideLayout ? 21 / 9 : 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: canWatch
                          ? _buildVideoPlayer(
                              video,
                              resumeSeconds:
                                  widget.initialPositionSeconds ??
                                  historyItem?.durationWatchedSeconds ??
                                  0,
                            )
                          : _buildPremiumLocked(
                              isAuthenticated: isAuthenticated,
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: isWideLayout
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _buildPrimaryContent(
                                      context: context,
                                      video: video,
                                      averageRating: averageRating,
                                      totalRatings: totalRatings,
                                      isAuthenticated: isAuthenticated,
                                      canRate: canRate,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 4, child: sidePanel),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPrimaryContent(
                                    context: context,
                                    video: video,
                                    averageRating: averageRating,
                                    totalRatings: totalRatings,
                                    isAuthenticated: isAuthenticated,
                                    canRate: canRate,
                                  ),
                                  const SizedBox(height: 16),
                                  sidePanel,
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPrimaryContent({
    required BuildContext context,
    required dynamic video,
    required double averageRating,
    required int totalRatings,
    required bool isAuthenticated,
    required bool canRate,
  }) {
    final settings = ref.watch(allSettingsProvider).valueOrNull ?? const {};
    final authState = ref.watch(authProvider);
    final isPremiumUser = authState.user?.isPremium == true;

    final freeMaxQuality = settings[SettingKeys.freeTierMaxQuality] ??
        settings[SettingKeys.defaultStreamQuality] ??
        '720p HD';
    final premiumMaxQuality =
        settings[SettingKeys.premiumTierMaxQuality] ?? '1080p Full HD';
    final streamQuality = isPremiumUser ? premiumMaxQuality : freeMaxQuality;
    final bufferProfile =
        settings[SettingKeys.bufferProfile] ?? 'Standard (Balanced)';

    final activeQuality = _selectedQuality ?? streamQuality;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(video.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('${averageRating.toStringAsFixed(1)}/10'),
                const SizedBox(width: 6),
                Text(
                  '(${_ratingCountLabel(totalRatings)})',
                  style: TextStyle(color: context.textMuted),
                ),
              ],
            ),
            Text('${video.duration ~/ 60} min'),
            PopupMenuButton<String>(
              tooltip: 'Streaming Quality',
              color: context.surfaceBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: context.borderCol),
              ),
              onSelected: (val) {
                if (val.startsWith('locked:')) {
                  final label = val.replaceFirst('locked:', '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$label is reserved for VIP members.',
                            ),
                          ),
                        ],
                      ),
                      action: SnackBarAction(
                        label: 'Upgrade',
                        textColor: const Color(0xFFF59E0B),
                        onPressed: () => context.push('/plans'),
                      ),
                    ),
                  );
                  return;
                }
                setState(() {
                  _selectedQuality = val;
                });
              },
              itemBuilder: (ctx) {
                final options = getQualityOptionsForTier(
                  isPremium: isPremiumUser,
                  maxQuality: freeMaxQuality,
                );
                return options.map((opt) {
                  final isCurrent = (opt.label == activeQuality) ||
                      (parseResolutionNumeric(opt.label) ==
                          parseResolutionNumeric(activeQuality));
                  return PopupMenuItem<String>(
                    value: opt.isLocked ? 'locked:${opt.label}' : opt.label,
                    child: Row(
                      children: [
                        Icon(
                          opt.isLocked
                              ? Icons.lock_rounded
                              : (isCurrent
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded),
                          size: 16,
                          color: opt.isLocked
                              ? Colors.grey
                              : (isCurrent
                                  ? const Color(0xFF1F9DCC)
                                  : context.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            opt.label,
                            style: TextStyle(
                              color: opt.isLocked
                                  ? context.textMuted
                                  : context.textPrimary,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (opt.isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPremiumUser
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : const Color(0xFF1F9DCC).withValues(alpha: 0.15),
                  border: Border.all(
                    color: isPremiumUser
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF1F9DCC),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPremiumUser
                          ? Icons.workspace_premium_rounded
                          : Icons.hd_rounded,
                      size: 12,
                      color: isPremiumUser
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF1F9DCC),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPremiumUser
                          ? (activeQuality.contains('4K')
                              ? '4K Ultra HD • VIP'
                              : activeQuality.contains('1080')
                                  ? '1080p FHD • VIP'
                                  : '$activeQuality • VIP')
                          : (activeQuality.contains('720')
                              ? '720p HD • Free Cap'
                              : activeQuality.contains('480')
                                  ? '480p SD • Free Cap'
                                  : '$activeQuality • Free Cap'),
                      style: TextStyle(
                        color: isPremiumUser
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF1F9DCC),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 14,
                      color: isPremiumUser
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF1F9DCC),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.elevatedBg,
                border: Border.all(color: context.borderCol),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed_rounded, size: 12, color: context.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    bufferProfile.contains('Aggressive')
                        ? 'Fast Start Preload'
                        : bufferProfile.contains('Data Saver')
                        ? 'Data Saver Buffer'
                        : 'Balanced Buffer',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (video.requiresPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Premium',
                  style: TextStyle(color: Colors.red, fontSize: 10),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.surfaceBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderCol),
          ),
          child: Row(
            children: [
              Icon(
                canRate
                    ? Icons.star_outline_rounded
                    : Icons.lock_outline_rounded,
                color: canRate ? const Color(0xFFFFB44C) : context.textMuted,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _ratingAccessLabel(
                    isAuthenticated: isAuthenticated,
                    isPremiumVideo: video.requiresPremium,
                    canRate: canRate,
                  ),
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'About this video',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          video.description,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
        ),
        if (video.cast != null && video.cast!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Cast', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: video.cast!
                .map<Widget>((actor) => Chip(label: Text(actor)))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSidePanel({
    required BuildContext context,
    required String videoId,
    required bool isAuthenticated,
    required bool videoRequiresPremium,
    required bool canRate,
    required int? currentUserRating,
    required bool isSubmittingRating,
    required bool isInWatchlist,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildViewerRatingCard(
          context: context,
          isAuthenticated: isAuthenticated,
          videoRequiresPremium: videoRequiresPremium,
          canRate: canRate,
          currentUserRating: currentUserRating,
          isSubmittingRating: isSubmittingRating,
        ),
        const SizedBox(height: 16),
        _buildActionButtons(
          context: context,
          videoId: videoId,
          isAuthenticated: isAuthenticated,
          isInWatchlist: isInWatchlist,
        ),
      ],
    );
  }

  Widget _buildViewerRatingCard({
    required BuildContext context,
    required bool isAuthenticated,
    required bool videoRequiresPremium,
    required bool canRate,
    required int? currentUserRating,
    required bool isSubmittingRating,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Viewer Rating',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (currentUserRating != null) ...[
            Text(
              'Your rating: $currentUserRating/10',
              style: const TextStyle(
                color: Color(0xFFFFB44C),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You can rate each video only once.',
              style: TextStyle(color: context.textMuted),
            ),
          ] else if (canRate && !_showRatingPicker) ...[
            Text(
              'Tap the star when you want to rate this video.',
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 14),
            Center(
              child: SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _showRatingPicker = true;
                    });
                  },
                  iconSize: 30,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x1FFFB44C),
                    shape: const CircleBorder(),
                    side: const BorderSide(color: Color(0x66FFB44C)),
                  ),
                  icon: const Icon(
                    Icons.star_outline_rounded,
                    color: Color(0xFFFFB44C),
                  ),
                ),
              ),
            ),
          ] else if (canRate) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pick a score from 1 to 10. You can submit only once.',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: isSubmittingRating
                      ? null
                      : () {
                          setState(() {
                            _showRatingPicker = false;
                            _selectedRating = 0;
                          });
                        },
                  child: const Text('Close'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(10, (index) {
                final value = index + 1;
                final selected = _selectedRating == value;
                return ChoiceChip(
                  label: Text('$value'),
                  selected: selected,
                  onSelected: isSubmittingRating
                      ? null
                      : (_) {
                          setState(() {
                            _selectedRating = value;
                          });
                        },
                  selectedColor: const Color(0xFFFFB44C),
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : context.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: context.elevatedBg,
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFFFFB44C)
                        : context.borderCol,
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedRating == 0 || isSubmittingRating
                    ? null
                    : () async {
                        await ref
                            .read(
                              videoRatingSubmissionProvider(
                                widget.videoId,
                              ).notifier,
                            )
                            .submitRating(_selectedRating);
                      },
                icon: isSubmittingRating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.star_rate_rounded),
                label: Text(
                  isSubmittingRating
                      ? 'Submitting...'
                      : 'Submit $_selectedRating/10',
                ),
              ),
            ),
          ] else ...[
            Text(
              _ratingAccessLabel(
                isAuthenticated: isAuthenticated,
                isPremiumVideo: videoRequiresPremium,
                canRate: canRate,
              ),
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required BuildContext context,
    required String videoId,
    required bool isAuthenticated,
    required bool isInWatchlist,
  }) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              if (!isAuthenticated) {
                final loginUri = Uri(
                  path: '/login',
                  queryParameters: {'redirectTo': '/video/$videoId'},
                );
                context.go(loginUri.toString());
                return;
              }

              if (isInWatchlist) {
                ref
                    .read(watchlistProvider.notifier)
                    .removeFromWatchlist(videoId);
              } else {
                ref.read(watchlistProvider.notifier).addToWatchlist(videoId);
              }
            },
            icon: Icon(
              isInWatchlist ? Icons.bookmark_added : Icons.bookmark_add,
            ),
            label: Text(isInWatchlist ? 'Saved' : 'Save'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // Share functionality
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer(VideoModel video, {required int resumeSeconds}) {
    _activeVideo = video;
    _ensureHistorySeeded(video, resumeSeconds);

    final settings = ref.watch(allSettingsProvider).valueOrNull ?? const {};
    final authState = ref.watch(authProvider);
    final isPremiumUser = authState.user?.isPremium == true;

    final freeMaxQuality = settings[SettingKeys.freeTierMaxQuality] ??
        settings[SettingKeys.defaultStreamQuality] ??
        '720p HD';
    final premiumMaxQuality =
        settings[SettingKeys.premiumTierMaxQuality] ?? '1080p Full HD';
    final streamQuality = isPremiumUser ? premiumMaxQuality : freeMaxQuality;
    final activeQuality = _selectedQuality ?? streamQuality;

    final libraryId = settings[SettingKeys.bunnyLibraryId];
    final pullZone = settings[SettingKeys.bunnyPullZone];
    final isBunny = video.mediaProvider == 'bunny' ||
        isBunnyStreamUrl(video.videoUrl) ||
        (video.providerVideoId != null && video.providerVideoId!.isNotEmpty);

    if (kIsWeb && isBunny) {
      String playableUrl = video.videoUrl;

      // Tier-capped direct MP4 enforcement:
      // When a free user is restricted to a resolution (e.g. 480p or 720p),
      // we resolve the direct play_480p.mp4 / play_720p.mp4 stream.
      // This physically prevents higher resolutions from appearing in the player.
      final directTierUrl = (!isPremiumUser &&
              !activeQuality.toLowerCase().contains('auto'))
          ? resolveTierCappedBunnyMediaUrl(
              videoUrl: video.videoUrl,
              providerVideoId: video.providerVideoId,
              libraryId: libraryId,
              configuredPullZone: pullZone,
              quality: activeQuality,
            )
          : null;

      if (directTierUrl != null) {
        playableUrl = directTierUrl;
      } else if (libraryId != null &&
          libraryId.isNotEmpty &&
          video.providerVideoId != null &&
          video.providerVideoId!.isNotEmpty &&
          !playableUrl.contains('iframe.mediadelivery.net')) {
        playableUrl =
            'https://iframe.mediadelivery.net/embed/$libraryId/${video.providerVideoId}';
      }

      final bufferProfile = settings[SettingKeys.bufferProfile];

      return BunnyWebPlayer(
        key: ValueKey(
          'bunny_${video.id}_${playableUrl}_${activeQuality}_${bufferProfile ?? "standard"}_$isPremiumUser',
        ),
        videoUrl: playableUrl,
        libraryId: libraryId,
        bufferProfile: bufferProfile,
        streamQuality: activeQuality,
        initialPositionSeconds: resumeSeconds,
        onPositionChanged: (position) {
          _saveHistoryPosition(
            video: video,
            watchedSeconds: position,
          );
        },
      );
    }

    final controller = _videoPlayerController;

    if (controller == null || _initializedVideoUrl != video.videoUrl) {
      _initializeVideoPlayer(video);
    }

    final activeController = _videoPlayerController;
    final isInitialized = activeController?.value.isInitialized ?? false;

    if (isInitialized && activeController != null) {
      _maybeApplyResumePosition(
        video: video,
        controller: activeController,
        resumeSeconds: resumeSeconds,
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        isInitialized && activeController != null
            ? VideoPlayer(activeController)
            : Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
              ),
        if (isInitialized && activeController != null)
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                unawaited(activeController.pause());
              } else {
                unawaited(activeController.play());
              }
            },
            child: _isPlaying
                ? const SizedBox()
                : Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildPremiumLocked({required bool isAuthenticated}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Premium Content',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAuthenticated
                ? 'Upgrade your plan to watch this video'
                : 'Create an account to continue to premium plans',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (isAuthenticated) {
                context.push('/plans');
                return;
              }

              final registerUri = Uri(
                path: '/register',
                queryParameters: {'redirectTo': '/plans'},
              );
              context.go(registerUri.toString());
            },
            child: Text(isAuthenticated ? 'View Plans' : 'Create Account'),
          ),
          if (!isAuthenticated)
            TextButton(
              onPressed: () {
                final loginUri = Uri(
                  path: '/login',
                  queryParameters: {'redirectTo': '/plans'},
                );
                context.go(loginUri.toString());
              },
              child: const Text('Already have an account? Sign in'),
            ),
        ],
      ),
    );
  }
}
