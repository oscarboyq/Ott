import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:video/common/widgets/common_widgets.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/video_catalog_provider.dart';
import 'package:video/core/providers/video_rating_provider.dart';
import 'package:video/core/providers/watchlist_provider.dart';
import 'package:video/features/video/presentation/widgets/bunny_web_player.dart';

class VideoDetailsPage extends ConsumerStatefulWidget {
  const VideoDetailsPage({required this.videoId, super.key});

  final String videoId;

  @override
  ConsumerState<VideoDetailsPage> createState() => _VideoDetailsPageState();
}

class _VideoDetailsPageState extends ConsumerState<VideoDetailsPage> {
  VideoPlayerController? _videoPlayerController;
  bool _isPlaying = false;
  String? _initializedVideoUrl;
  int _selectedRating = 0;

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
    // Initialize video player - will be set when video data loads
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  void _initializeVideoPlayer(String videoUrl) {
    if (_initializedVideoUrl == videoUrl && _videoPlayerController != null) {
      return;
    }

    _videoPlayerController?.dispose();
    _initializedVideoUrl = videoUrl;

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoPlayerController = controller;

    controller
        .initialize()
        .then((_) {
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

  bool _isBunnyStreamUrl(String videoUrl) {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) {
      return false;
    }

    return uri.host.contains('mediadelivery.net') ||
        uri.host.contains('b-cdn.net') ||
        videoUrl.contains('/playlist.m3u8');
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));
    final authState = ref.watch(authProvider);
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
          body: ListView(
            children: [
              // Video Player Container
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: canWatch
                      ? _buildVideoPlayer(video.videoUrl)
                      : _buildPremiumLocked(isAuthenticated: isAuthenticated),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      video.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),

                    // Rating & Info
                    Row(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text('${averageRating.toStringAsFixed(1)}/10'),
                            const SizedBox(width: 6),
                            Text(
                              '(${_ratingCountLabel(totalRatings)})',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Text('${video.duration ~/ 60} min'),
                        const SizedBox(width: 16),
                        if (video.requiresPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                            color: canRate
                                ? const Color(0xFFFFB44C)
                                : Colors.white54,
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
                    const SizedBox(height: 16),
                    Container(
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
                          Text(
                            'Viewer Rating',
                            style: Theme.of(context).textTheme.titleMedium,
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
                            const Text(
                              'You can rate each video only once.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ] else if (canRate) ...[
                            const Text(
                              'Pick a score from 1 to 10. You can submit only once.',
                              style: TextStyle(color: Colors.white70),
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
                                    color: selected
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  backgroundColor: const Color(0xFF162235),
                                  side: const BorderSide(
                                    color: Color(0xFF243247),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    _selectedRating == 0 || isSubmittingRating
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
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
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
                                isPremiumVideo: video.requiresPremium,
                                canRate: canRate,
                              ),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              if (!isAuthenticated) {
                                final loginUri = Uri(
                                  path: '/login',
                                  queryParameters: {
                                    'redirectTo': '/video/${video.id}',
                                  },
                                );
                                context.go(loginUri.toString());
                                return;
                              }

                              if (isInWatchlist) {
                                ref
                                    .read(watchlistProvider.notifier)
                                    .removeFromWatchlist(video.id);
                              } else {
                                ref
                                    .read(watchlistProvider.notifier)
                                    .addToWatchlist(video.id);
                              }
                            },
                            icon: Icon(
                              isInWatchlist
                                  ? Icons.bookmark_added
                                  : Icons.bookmark_add,
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
                    ),
                    const SizedBox(height: 24),

                    // Description
                    Text(
                      'About this video',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      video.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cast & Crew
                    if (video.cast != null && video.cast!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cast',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: video.cast!
                                .map((actor) => Chip(label: Text(actor)))
                                .toList(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    if (kIsWeb && _isBunnyStreamUrl(videoUrl)) {
      return BunnyWebPlayer(videoUrl: videoUrl);
    }

    final controller = _videoPlayerController;

    if (controller == null || _initializedVideoUrl != videoUrl) {
      _initializeVideoPlayer(videoUrl);
    }

    final activeController = _videoPlayerController;
    final isInitialized = activeController?.value.isInitialized ?? false;

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
              setState(() {
                if (_isPlaying) {
                  activeController.pause();
                } else {
                  activeController.play();
                }
                _isPlaying = !_isPlaying;
              });
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
