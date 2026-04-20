import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/video_catalog_provider.dart';
import 'package:video/core/providers/video_rating_provider.dart';
import 'package:video/core/providers/watch_history_provider.dart';
import 'package:video/core/utils/playback_source_resolver.dart';
import 'package:video/features/video/presentation/widgets/bunny_web_player.dart';
import 'package:video_player/video_player.dart';

class ReelsPage extends ConsumerStatefulWidget {
  const ReelsPage({super.key, this.initialReelId});

  final String? initialReelId;

  @override
  ConsumerState<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends ConsumerState<ReelsPage> {
  late final PageController _pageController;
  VideoPlayerController? _videoPlayerController;
  String? _activeVideoUrl;
  int _currentIndex = 0;
  bool _isPlaying = true;
  bool _initialIndexResolved = false;
  final Set<String> _locallyRatedReelIds = <String>{};
  final Map<String, int> _optimisticReelStarCounts = <String, int>{};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  bool _canWatchReel({required VideoModel reel, required bool isPremiumUser}) {
    if (!reel.requiresPremium) {
      return true;
    }

    return isPremiumUser;
  }

  bool _canRateReel({
    required VideoModel reel,
    required bool isAuthenticated,
    required bool isPremiumUser,
  }) {
    if (!isAuthenticated) {
      return false;
    }

    if (!reel.requiresPremium) {
      return true;
    }

    return isPremiumUser;
  }

  void _recordReelHistory(VideoModel reel) {
    ref
        .read(watchHistoryProvider.notifier)
        .recordPlayback(video: reel, watchedSeconds: 0);
  }

  Future<void> _clearActivePlayback() async {
    final previousController = _videoPlayerController;
    _videoPlayerController = null;
    _activeVideoUrl = null;
    _isPlaying = false;
    await previousController?.dispose();

    if (mounted) {
      setState(() {});
    }
  }

  void _syncInitialIndex(List<VideoModel> reels) {
    if (_initialIndexResolved || reels.isEmpty) {
      return;
    }

    _initialIndexResolved = true;
    final initialReelId = widget.initialReelId;
    final authState = ref.read(authProvider);
    final isPremiumUser = authState.user?.isPremium == true;
    if (initialReelId == null || initialReelId.isEmpty) {
      final firstReel = reels.first;
      if (_canWatchReel(reel: firstReel, isPremiumUser: isPremiumUser)) {
        _initializeControllerFor(firstReel.videoUrl);
        _recordReelHistory(firstReel);
      }
      return;
    }

    final initialIndex = reels.indexWhere((reel) => reel.id == initialReelId);
    if (initialIndex <= 0) {
      final firstReel = reels.first;
      if (_canWatchReel(reel: firstReel, isPremiumUser: isPremiumUser)) {
        _initializeControllerFor(firstReel.videoUrl);
        _recordReelHistory(firstReel);
      }
      return;
    }

    _currentIndex = initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _pageController.jumpToPage(initialIndex);
      final reel = reels[initialIndex];
      if (_canWatchReel(reel: reel, isPremiumUser: isPremiumUser)) {
        _initializeControllerFor(reel.videoUrl);
        _recordReelHistory(reel);
      }
      setState(() {});
    });
  }

  void _ensurePlaybackState({
    required VideoModel activeReel,
    required bool canWatch,
  }) {
    if (!canWatch) {
      if (_videoPlayerController != null || _activeVideoUrl != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _clearActivePlayback();
          }
        });
      }
      return;
    }

    if (_activeVideoUrl != activeReel.videoUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeControllerFor(activeReel.videoUrl);
        }
      });
    }
  }

  Future<void> _initializeControllerFor(String videoUrl) async {
    if (_activeVideoUrl == videoUrl) {
      return;
    }

    final previousController = _videoPlayerController;
    _videoPlayerController = null;
    _activeVideoUrl = videoUrl;
    _isPlaying = true;
    await previousController?.dispose();

    if (isBunnyStreamUrl(videoUrl)) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final resolvedVideoUrl = resolvePlayableVideoUrl(videoUrl);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(resolvedVideoUrl),
    );
    _videoPlayerController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load this reel.')),
        );
        setState(() {});
      }
    }
  }

  Future<void> _handlePageChanged(int index, List<VideoModel> reels) async {
    final authState = ref.read(authProvider);
    final isPremiumUser = authState.user?.isPremium == true;
    final activeReel = reels[index];
    final canWatch = _canWatchReel(
      reel: activeReel,
      isPremiumUser: isPremiumUser,
    );

    setState(() {
      _currentIndex = index;
      _isPlaying = canWatch;
    });

    if (canWatch) {
      await _initializeControllerFor(activeReel.videoUrl);
      _recordReelHistory(activeReel);
      return;
    }

    await _clearActivePlayback();
  }

  void _togglePlayback() {
    final controller = _videoPlayerController;
    if (controller == null || !_activeVideoUrlIsNative) {
      return;
    }

    setState(() {
      if (_isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  bool get _activeVideoUrlIsNative =>
      _activeVideoUrl != null && !isBunnyStreamUrl(_activeVideoUrl!);

  String _starCountLabel(int count) {
    if (count == 1) {
      return '1 user';
    }
    return '$count users';
  }

  Future<void> _submitQuickStarRating({
    required BuildContext context,
    required String reelId,
    required VideoModel reel,
    required bool isAuthenticated,
    required bool canRate,
    required int? currentUserRating,
  }) async {
    if (!isAuthenticated) {
      final loginUri = Uri(
        path: '/login',
        queryParameters: {
          'redirectTo': Uri(
            path: '/reels',
            queryParameters: {'reelId': reel.id},
          ).toString(),
        },
      );
      context.go(loginUri.toString());
      return;
    }

    if (!canRate) {
      context.push('/plans');
      return;
    }

    if (currentUserRating != null || _locallyRatedReelIds.contains(reelId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already rated this reel.')),
      );
      return;
    }

    await ref
        .read(videoRatingSubmissionProvider(reelId).notifier)
        .submitRating(10);

    final updatedState = ref.read(videoRatingSubmissionProvider(reelId));
    if (!updatedState.hasError && mounted) {
      setState(() {
        _locallyRatedReelIds.add(reelId);
        final optimisticCount = reel.ratingCount + 1;
        final currentOptimisticCount = _optimisticReelStarCounts[reelId];
        if (currentOptimisticCount == null ||
            optimisticCount > currentOptimisticCount) {
          _optimisticReelStarCounts[reelId] = optimisticCount;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reelsAsync = ref.watch(reelsCatalogProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.isAuthenticated;
    final isPremiumUser = authState.user?.isPremium == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: reelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white54,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(reelsCatalogProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (reels) {
          _syncInitialIndex(reels);

          if (reels.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.video_collection_outlined,
                      color: Colors.white38,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No reels yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add reel content from the admin panel to populate this feed.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              ),
            );
          }

          final activeReel = reels[_currentIndex];
          final canWatchActiveReel = _canWatchReel(
            reel: activeReel,
            isPremiumUser: isPremiumUser,
          );
          final canRateActiveReel = _canRateReel(
            reel: activeReel,
            isAuthenticated: isAuthenticated,
            isPremiumUser: isPremiumUser,
          );
          final currentUserRatingAsync = ref.watch(
            currentUserVideoRatingProvider(activeReel.id),
          );
          final activeReelRatingStatsAsync = ref.watch(
            videoRatingStatsProvider(activeReel.id),
          );
          final ratingSubmissionState = ref.watch(
            videoRatingSubmissionProvider(activeReel.id),
          );
          final currentUserRating =
              currentUserRatingAsync.valueOrNull ??
              (_locallyRatedReelIds.contains(activeReel.id) ? 10 : null);
          final activeReelRatingStats = activeReelRatingStatsAsync.valueOrNull;
          final isSubmittingRating = ratingSubmissionState.isLoading;
          final optimisticStarCount = _optimisticReelStarCounts[activeReel.id];
          final displayedStarCount =
              <int>[
                activeReelRatingStats?.count ?? activeReel.ratingCount,
                optimisticStarCount ?? 0,
                currentUserRating != null ? 1 : 0,
              ].reduce(
                (currentMax, value) => value > currentMax ? value : currentMax,
              );

          ref.listen<AsyncValue<void>>(
            videoRatingSubmissionProvider(activeReel.id),
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

          _ensurePlaybackState(
            activeReel: activeReel,
            canWatch: canWatchActiveReel,
          );

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                onPageChanged: (index) => _handlePageChanged(index, reels),
                itemBuilder: (context, index) {
                  final reel = reels[index];
                  final isActive = index == _currentIndex;
                  return _ReelPageItem(
                    reel: reel,
                    isActive: isActive,
                    isPlaying: isActive && _isPlaying,
                    canWatch: _canWatchReel(
                      reel: reel,
                      isPremiumUser: isPremiumUser,
                    ),
                    isAuthenticated: isAuthenticated,
                    videoPlayerController: isActive
                        ? _videoPlayerController
                        : null,
                    useBunnyPlayer: isActive && isBunnyStreamUrl(reel.videoUrl),
                    onTap: isActive ? _togglePlayback : null,
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                            return;
                          }
                          context.go('/');
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          'Reels ${_currentIndex + 1}/${reels.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 28,
                child: _ReelInfoOverlay(
                  reel: activeReel,
                  ratingCountLabel: _starCountLabel(displayedStarCount),
                  canRate: canRateActiveReel,
                  currentUserRating: currentUserRating,
                  isSubmittingRating: isSubmittingRating,
                  onRatePressed: isSubmittingRating
                      ? null
                      : () => _submitQuickStarRating(
                          context: context,
                          reelId: activeReel.id,
                          reel: activeReel,
                          isAuthenticated: isAuthenticated,
                          canRate: canRateActiveReel,
                          currentUserRating: currentUserRating,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReelPageItem extends StatelessWidget {
  const _ReelPageItem({
    required this.reel,
    required this.isActive,
    required this.isPlaying,
    required this.canWatch,
    required this.isAuthenticated,
    required this.videoPlayerController,
    required this.useBunnyPlayer,
    required this.onTap,
  });

  final VideoModel reel;
  final bool isActive;
  final bool isPlaying;
  final bool canWatch;
  final bool isAuthenticated;
  final VideoPlayerController? videoPlayerController;
  final bool useBunnyPlayer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _PosterBackground(reel: reel),
        if (isActive && canWatch)
          Positioned.fill(
            top: 92,
            right: 92,
            child: GestureDetector(
              onTap: onTap,
              child: useBunnyPlayer
                  ? BunnyWebPlayer(
                      videoUrl: reel.videoUrl,
                      capturePointerEvents: true,
                    )
                  : _NativePlayerSurface(
                      controller: videoPlayerController,
                      isPlaying: isPlaying,
                    ),
            ),
          ),
        if (isActive && !canWatch)
          Positioned.fill(
            child: _ReelAccessGate(
              reel: reel,
              isAuthenticated: isAuthenticated,
            ),
          ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x05000000),
                  Color(0xCC000000),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReelAccessGate extends StatelessWidget {
  const _ReelAccessGate({required this.reel, required this.isAuthenticated});

  final VideoModel reel;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    final redirectTo = Uri(
      path: '/reels',
      queryParameters: {'reelId': reel.id},
    ).toString();

    return Container(
      color: const Color(0x88000000),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xCC070B12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF05454).withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: Color(0xFFFFB44C),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Premium Reel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAuthenticated
                      ? 'Upgrade to Premium to watch this reel.'
                      : 'Sign in and upgrade to Premium to watch this reel.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (isAuthenticated) {
                        context.push('/plans');
                        return;
                      }

                      final loginUri = Uri(
                        path: '/login',
                        queryParameters: {'redirectTo': redirectTo},
                      );
                      context.go(loginUri.toString());
                    },
                    icon: Icon(
                      isAuthenticated ? Icons.workspace_premium : Icons.login,
                    ),
                    label: Text(
                      isAuthenticated ? 'View Plans' : 'Sign In to Continue',
                    ),
                  ),
                ),
                if (!isAuthenticated) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      final registerUri = Uri(
                        path: '/register',
                        queryParameters: {'redirectTo': redirectTo},
                      );
                      context.go(registerUri.toString());
                    },
                    child: const Text('Create Account'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterBackground extends StatelessWidget {
  const _PosterBackground({required this.reel});

  final VideoModel reel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: reel.thumbnailUrl.isEmpty
          ? const Center(
              child: Icon(
                Icons.video_collection_outlined,
                color: Colors.white24,
                size: 80,
              ),
            )
          : Image.network(
              reel.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white24,
                  size: 80,
                ),
              ),
            ),
    );
  }
}

class _NativePlayerSurface extends StatelessWidget {
  const _NativePlayerSurface({
    required this.controller,
    required this.isPlaying,
  });

  final VideoPlayerController? controller;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final activeController = controller;
    final isInitialized = activeController?.value.isInitialized ?? false;

    if (!isInitialized || activeController == null) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: activeController.value.size.width,
            height: activeController.value.size.height,
            child: VideoPlayer(activeController),
          ),
        ),
        if (!isPlaying)
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
      ],
    );
  }
}

class _ReelInfoOverlay extends StatelessWidget {
  const _ReelInfoOverlay({
    required this.reel,
    required this.ratingCountLabel,
    required this.canRate,
    required this.currentUserRating,
    required this.isSubmittingRating,
    required this.onRatePressed,
  });

  final VideoModel reel;
  final String ratingCountLabel;
  final bool canRate;
  final int? currentUserRating;
  final bool isSubmittingRating;
  final VoidCallback? onRatePressed;

  @override
  Widget build(BuildContext context) {
    final accentColor = currentUserRating != null
        ? const Color(0xFFFFD27A)
        : canRate
        ? const Color(0xFFFFB44C)
        : Colors.white54;
    final isEnabled = onRatePressed != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: reel.requiresPremium
                      ? const Color(0xFFF05454)
                      : const Color(0xFF21A45D),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  reel.requiresPremium ? 'PREMIUM' : 'FREE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                reel.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              if (reel.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  reel.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                reel.genre.isEmpty ? 'Reel' : reel.genre,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: IconButton(
                onPressed: onRatePressed,
                iconSize: 32,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x33000000),
                  disabledBackgroundColor: const Color(0x22000000),
                  shape: const CircleBorder(),
                  side: BorderSide(
                    color: isEnabled
                        ? Colors.white30
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                icon: isSubmittingRating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        currentUserRating != null
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: accentColor,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ratingCountLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}
