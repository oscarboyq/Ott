import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:video/common/widgets/common_widgets.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/video_catalog_provider.dart';
import 'package:video/core/providers/watch_history_provider.dart';
import 'package:video/core/providers/video_rating_provider.dart';
import 'package:video/core/providers/watchlist_provider.dart';
import 'package:video/core/utils/playback_source_resolver.dart';
import 'package:video/features/video/presentation/widgets/bunny_web_player.dart';

class VideoDetailsPage extends ConsumerStatefulWidget {
  const VideoDetailsPage({
    required this.videoId,
    this.autoPlay = false,
    super.key,
  });

  final String videoId;
  final bool autoPlay;

  @override
  ConsumerState<VideoDetailsPage> createState() => _VideoDetailsPageState();
}

class _VideoDetailsPageState extends ConsumerState<VideoDetailsPage> {
  VideoPlayerController? _videoPlayerController;
  bool _isPlaying = false;
  String? _initializedVideoUrl;
  int _selectedRating = 0;
  bool _showRatingPicker = false;
  VideoModel? _activeVideo;
  String? _recordedHistoryVideoId;
  String? _resumeAppliedVideoId;
  int _lastPersistedPositionSeconds = -1;
  String? _autoPlayedVideoId;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchHistoryProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _persistCurrentPlaybackPosition(force: true);
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
          await ref
              .read(watchHistoryProvider.notifier)
              .recordPlayback(video: video, watchedSeconds: 0);

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

  void _persistCurrentPlaybackPosition({bool force = false}) {
    final controller = _videoPlayerController;
    final video = _activeVideo;
    if (controller == null ||
        video == null ||
        !controller.value.isInitialized) {
      return;
    }

    _saveHistoryPosition(
      video: video,
      watchedSeconds: controller.value.position.inSeconds,
      force: force,
    );
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
    unawaited(
      ref
          .read(watchHistoryProvider.notifier)
          .recordPlayback(video: video, watchedSeconds: watchedSeconds),
    );
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
                                  historyItem?.durationWatchedSeconds ?? 0,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(video.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
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
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
            Text('${video.duration ~/ 60} min'),
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
            color: const Color(0xFF101826),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF243247)),
          ),
          child: Row(
            children: [
              Icon(
                canRate
                    ? Icons.star_outline_rounded
                    : Icons.lock_outline_rounded,
                color: canRate ? const Color(0xFFFFB44C) : Colors.white54,
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
                  style: const TextStyle(color: Colors.white70),
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
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400),
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
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243247)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Viewer Rating', style: Theme.of(context).textTheme.titleMedium),
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
            const Text(
              'You can rate each video only once.',
              style: TextStyle(color: Colors.white54),
            ),
          ] else if (canRate && !_showRatingPicker) ...[
            const Text(
              'Tap the star when you want to rate this video.',
              style: TextStyle(color: Colors.white70),
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
                    backgroundColor: const Color(0x1FFFFB44C),
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
                const Expanded(
                  child: Text(
                    'Pick a score from 1 to 10. You can submit only once.',
                    style: TextStyle(color: Colors.white70),
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
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: const Color(0xFF162235),
                  side: const BorderSide(color: Color(0xFF243247)),
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
              style: const TextStyle(color: Colors.white70),
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
    if (kIsWeb && isBunnyStreamUrl(video.videoUrl)) {
      if (_recordedHistoryVideoId != video.id) {
        _recordedHistoryVideoId = video.id;
        unawaited(
          ref
              .read(watchHistoryProvider.notifier)
              .recordPlayback(video: video, watchedSeconds: 0),
        );
      }
      return BunnyWebPlayer(videoUrl: video.videoUrl);
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
