import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/app/theme/app_theme.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/series_catalog_provider.dart';
import 'package:video/core/providers/watch_history_provider.dart';
import 'package:video/core/services/app_settings_service.dart';
import 'package:video/core/utils/playback_source_resolver.dart';
import 'package:video/features/video/presentation/widgets/bunny_web_player.dart';
import 'package:video/features/video/presentation/widgets/network_web_video_player.dart';
import 'package:video_player/video_player.dart';

class SeriesEpisodePage extends ConsumerStatefulWidget {
  const SeriesEpisodePage({
    required this.seriesId,
    required this.episodeId,
    this.initialPositionSeconds,
    super.key,
  });

  final String seriesId;
  final String episodeId;
  final int? initialPositionSeconds;

  @override
  ConsumerState<SeriesEpisodePage> createState() => _SeriesEpisodePageState();
}

class _SeriesEpisodePageState extends ConsumerState<SeriesEpisodePage> {
  VideoPlayerController? _controller;
  String? _activeEpisodeId;
  SeriesEpisodeModel? _activeEpisode;
  String? _playerError;
  int _lastSavedPosition = -1;
  String? _selectedQuality;
  String? _seededEpisodeId;
  WatchHistoryNotifier? _watchHistoryNotifier;
  SeriesModel? _activeSeries;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchHistoryNotifier = ref.read(watchHistoryProvider.notifier);
  }

  @override
  void didUpdateWidget(covariant SeriesEpisodePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeId != widget.episodeId) {
      _seededEpisodeId = null;
      _lastSavedPosition = -1;
    }
  }

  @override
  void deactivate() {
    // Capture state synchronously while still valid, then defer the provider
    // call via Future() so it runs after the current frame — Riverpod forbids
    // modifying providers during lifecycle callbacks like deactivate().
    final controller = _controller;
    final episode = _activeEpisode;
    final series = _activeSeries;
    final notifier = _watchHistoryNotifier;
    final position = (controller != null && controller.value.isInitialized)
        ? controller.value.position.inSeconds
        : _lastSavedPosition;
    if (series != null && episode != null && notifier != null && position > 0) {
      Future(() => notifier.recordSeriesPlayback(
            series: series,
            episode: episode,
            watchedSeconds: position,
          ));
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _controller?.removeListener(_handlePlaybackChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final episodeAsync = ref.watch(
      seriesEpisodeDetailsProvider(widget.episodeId),
    );
    final seriesAsync = ref.watch(seriesDetailsProvider(widget.seriesId));
    final episodeHistory = ref.watch(
      seriesEpisodeHistoryItemProvider(widget.episodeId),
    );
    final resumeSeconds = widget.initialPositionSeconds ??
        (episodeHistory?.hasResumePosition == true
            ? episodeHistory!.positionSeconds
            : 0);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        foregroundColor: context.textPrimary,
        title: Text(seriesAsync.valueOrNull?.title ?? 'Episode'),
      ),
      body: episodeAsync.when(
        data: (episode) {
          if (episode == null) {
            return Center(
              child: Text(
                'Episode not found',
                style: TextStyle(color: context.textMuted),
              ),
            );
          }

          final series = seriesAsync.valueOrNull;
          _activeSeries = series;
          if (series != null) {
            _ensureEpisodeHistorySeeded(series, episode, resumeSeconds);
          }
          _ensureController(episode, resumeSeconds);
          final seasonEpisodesAsync = ref.watch(
            seasonEpisodesProvider(episode.seasonId),
          );

          final settings =
              ref.watch(allSettingsProvider).valueOrNull ?? const {};
          final authState = ref.watch(authProvider);
          final isPremiumUser = authState.user?.isPremium == true;

          final freeMaxQuality = settings[SettingKeys.freeTierMaxQuality] ??
              settings[SettingKeys.defaultStreamQuality] ??
              '720p HD';
          final premiumMaxQuality =
              settings[SettingKeys.premiumTierMaxQuality] ?? '1080p Full HD';
          final streamQuality = isPremiumUser ? premiumMaxQuality : freeMaxQuality;
          final activeQuality = _selectedQuality ?? streamQuality;

          final autoplayNext =
              settings[SettingKeys.autoplayNextEpisode] != 'false';
          final bufferProfile =
              settings[SettingKeys.bufferProfile] ?? 'Standard (Balanced)';
          final bunnyLibraryId = settings[SettingKeys.bunnyLibraryId];
          final bunnyPullZone = settings[SettingKeys.bunnyPullZone];

          return seasonEpisodesAsync.when(
            data: (seasonEpisodes) => _EpisodePageContent(
              episode: episode,
              seriesTitle: seriesAsync.valueOrNull?.title ?? '',
              controller: _controller,
              playerError: _playerError,
              onPlayPause: _togglePlayback,
              seasonEpisodes: seasonEpisodes,
              autoplayNextEnabled: autoplayNext,
              streamQuality: activeQuality,
              freeMaxQuality: freeMaxQuality,
              bufferProfile: bufferProfile,
              bunnyLibraryId: bunnyLibraryId,
              bunnyPullZone: bunnyPullZone,
              isPremiumUser: isPremiumUser,
              initialPositionSeconds: resumeSeconds,
              onPositionChanged: series != null
                  ? (pos) => _handleWebPositionChanged(series, episode, pos)
                  : null,
              onQualityChanged: (q) {
                setState(() {
                  _selectedQuality = q;
                });
              },
              onEpisodeTap: (item) {
                if (item.id == episode.id) {
                  return;
                }
                context.push('/series/${widget.seriesId}/episode/${item.id}');
              },
            ),
            loading: () => _EpisodePageContent(
              episode: episode,
              seriesTitle: seriesAsync.valueOrNull?.title ?? '',
              controller: _controller,
              playerError: _playerError,
              onPlayPause: _togglePlayback,
              seasonEpisodes: const [],
              episodesLoading: true,
              autoplayNextEnabled: autoplayNext,
              streamQuality: activeQuality,
              freeMaxQuality: freeMaxQuality,
              bufferProfile: bufferProfile,
              bunnyLibraryId: bunnyLibraryId,
              bunnyPullZone: bunnyPullZone,
              onEpisodeTap: (_) {},
            ),
            error: (_, _) => _EpisodePageContent(
              episode: episode,
              seriesTitle: seriesAsync.valueOrNull?.title ?? '',
              controller: _controller,
              playerError: _playerError,
              onPlayPause: _togglePlayback,
              seasonEpisodes: const [],
              episodesError: 'Unable to load season episodes',
              autoplayNextEnabled: autoplayNext,
              streamQuality: activeQuality,
              freeMaxQuality: freeMaxQuality,
              bufferProfile: bufferProfile,
              bunnyLibraryId: bunnyLibraryId,
              bunnyPullZone: bunnyPullZone,
              onEpisodeTap: (_) {},
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Unable to load episode',
            style: TextStyle(color: context.textMuted),
          ),
        ),
      ),
    );
  }

  void _ensureEpisodeHistorySeeded(
    SeriesModel series,
    SeriesEpisodeModel episode,
    int resumeSeconds,
  ) {
    if (_seededEpisodeId == episode.id) return;
    _seededEpisodeId = episode.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = _watchHistoryNotifier ??
          (mounted ? ref.read(watchHistoryProvider.notifier) : null);
      if (notifier != null) {
        unawaited(
          notifier.recordSeriesPlayback(
            series: series,
            episode: episode,
            watchedSeconds: resumeSeconds,
          ),
        );
      }
    });
  }

  void _ensureController(SeriesEpisodeModel episode, int resumeSeconds) {
    if (_activeEpisodeId == episode.id && _controller != null) {
      return;
    }

    unawaited(_persistProgress(force: true));
    _controller?.removeListener(_handlePlaybackChanged);
    _controller?.dispose();

    _activeEpisodeId = episode.id;
    _activeEpisode = episode;
    _playerError = null;
    _lastSavedPosition = resumeSeconds > 0 ? resumeSeconds : -1;

    if (kIsWeb) {
      _controller = null;
      return;
    }

    final resolvedVideoUrl = resolvePlayableVideoUrl(episode.videoUrl);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(resolvedVideoUrl),
    );
    _controller = controller;
    controller.addListener(_handlePlaybackChanged);
    unawaited(
      controller
          .initialize()
          .then((_) {
            if (resumeSeconds > 0) {
              final total = controller.value.duration.inSeconds;
              final seek = total > 1
                  ? resumeSeconds.clamp(0, total - 1)
                  : resumeSeconds;
              unawaited(controller.seekTo(Duration(seconds: seek)));
            }
            if (mounted) {
              setState(() {});
            }
          })
          .catchError((Object _) {
            if (!mounted) {
              return;
            }

            setState(() {
              _playerError =
                  'This episode could not be played in your browser.';
            });
          }),
    );
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      controller.pause();
      return;
    }

    controller.play();
  }

  void _handlePlaybackChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final position = controller.value.position.inSeconds;
    if ((position - _lastSavedPosition).abs() < 10) {
      return;
    }

    _lastSavedPosition = position;
    unawaited(_persistProgress());

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _persistProgress({bool force = false}) async {
    final controller = _controller;
    final episode = _activeEpisode;
    if (controller == null ||
        episode == null ||
        !controller.value.isInitialized) {
      return;
    }

    final position = controller.value.position.inSeconds;
    if (!force && position == 0) {
      return;
    }

    final series = _activeSeries;
    // Use only cached notifier — never call ref.read here.
    final notifier = _watchHistoryNotifier;
    if (series == null || notifier == null) {
      return;
    }

    try {
      await notifier.recordSeriesPlayback(
        series: series,
        episode: episode,
        watchedSeconds: position,
      );
    } catch (_) {
      // Ignore guest or transient save failures for now.
    }
  }

  void _handleWebPositionChanged(
    SeriesModel series,
    SeriesEpisodeModel episode,
    int position,
  ) {
    if ((position - _lastSavedPosition).abs() < 5) {
      return;
    }

    _lastSavedPosition = position;
    // Use only cached notifier — never call ref.read here.
    final notifier = _watchHistoryNotifier;
    if (notifier != null) {
      unawaited(
        notifier.recordSeriesPlayback(
          series: series,
          episode: episode,
          watchedSeconds: position,
        ),
      );
    }
  }
}

class _EpisodePageContent extends StatelessWidget {
  const _EpisodePageContent({
    required this.episode,
    required this.seriesTitle,
    required this.controller,
    required this.playerError,
    required this.onPlayPause,
    required this.seasonEpisodes,
    required this.onEpisodeTap,
    this.autoplayNextEnabled = true,
    this.streamQuality = 'Auto (Adaptive Bitrate)',
    this.freeMaxQuality,
    this.bufferProfile = 'Standard (Balanced)',
    this.bunnyLibraryId,
    this.bunnyPullZone,
    this.isPremiumUser = false,
    this.episodesLoading = false,
    this.episodesError,
    this.initialPositionSeconds,
    this.onPositionChanged,
    this.onQualityChanged,
  });

  final SeriesEpisodeModel episode;
  final String seriesTitle;
  final VideoPlayerController? controller;
  final String? playerError;
  final VoidCallback onPlayPause;
  final List<SeriesEpisodeModel> seasonEpisodes;
  final ValueChanged<SeriesEpisodeModel> onEpisodeTap;
  final bool autoplayNextEnabled;
  final String streamQuality;
  final String? freeMaxQuality;
  final String bufferProfile;
  final String? bunnyLibraryId;
  final String? bunnyPullZone;
  final bool isPremiumUser;
  final bool episodesLoading;
  final String? episodesError;
  final int? initialPositionSeconds;
  final ValueChanged<int>? onPositionChanged;
  final ValueChanged<String>? onQualityChanged;

  @override
  Widget build(BuildContext context) {
    final videoValue = controller?.value;
    final isReady = videoValue?.isInitialized ?? false;
    final resolvedVideoUrl = resolvePlayableVideoUrl(episode.videoUrl);
    final useWebVideoSurface = kIsWeb;

    final directTierUrl = (!isPremiumUser &&
            !streamQuality.toLowerCase().contains('auto'))
        ? resolveTierCappedBunnyMediaUrl(
            videoUrl: episode.videoUrl,
            libraryId: bunnyLibraryId,
            configuredPullZone: bunnyPullZone,
            quality: streamQuality,
          )
        : null;
    final effectivePlayableUrl = directTierUrl ?? episode.videoUrl;

    final currentIndex = seasonEpisodes.indexWhere((e) => e.id == episode.id);
    final nextEpisode = (currentIndex != -1 && currentIndex + 1 < seasonEpisodes.length)
        ? seasonEpisodes[currentIndex + 1]
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        AspectRatio(
          aspectRatio: isReady ? videoValue!.aspectRatio : 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: context.elevatedBg,
              child: useWebVideoSurface
                  ? (isBunnyStreamUrl(episode.videoUrl)
                        ? BunnyWebPlayer(
                            key: ValueKey(
                              'bunny_ep_${episode.id}_${effectivePlayableUrl}_${streamQuality}_${bufferProfile}_$isPremiumUser',
                            ),
                            videoUrl: effectivePlayableUrl,
                            libraryId: bunnyLibraryId,
                            bufferProfile: bufferProfile,
                            streamQuality: streamQuality,
                            initialPositionSeconds: initialPositionSeconds,
                            onPositionChanged: onPositionChanged,
                          )
                        : NetworkWebVideoPlayer(
                            videoUrl: resolvedVideoUrl,
                            bufferProfile: bufferProfile,
                            initialPositionSeconds: initialPositionSeconds,
                            onPositionChanged: onPositionChanged,
                          ))
                  : isReady
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(controller!),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton.small(
                            onPressed: onPlayPause,
                            backgroundColor: const Color(0xFFF05454),
                            child: Icon(
                              videoValue!.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                        ),
                      ],
                    )
                  : playerError != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: context.textMuted,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            playerError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF05454),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Playback Policy Badges Row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
                onQualityChanged?.call(val);
              },
              itemBuilder: (ctx) {
                final options = getQualityOptionsForTier(
                  isPremium: isPremiumUser,
                  maxQuality: freeMaxQuality ?? streamQuality,
                );
                return options.map((opt) {
                  final isCurrent = (opt.label == streamQuality) ||
                      (parseResolutionNumeric(opt.label) ==
                          parseResolutionNumeric(streamQuality));
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
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPremiumUser
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : const Color(0xFF1F9DCC).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPremiumUser
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF1F9DCC),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPremiumUser
                          ? Icons.workspace_premium_rounded
                          : Icons.hd_rounded,
                      size: 14,
                      color: isPremiumUser
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF1F9DCC),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPremiumUser
                          ? (streamQuality.contains('4K')
                              ? '4K Ultra HD • VIP'
                              : streamQuality.contains('1080')
                                  ? '1080p FHD • VIP'
                                  : '$streamQuality • VIP')
                          : (streamQuality.contains('720')
                              ? '720p HD • Free Cap'
                              : streamQuality.contains('480')
                                  ? '480p SD • Free Cap'
                                  : '$streamQuality • Free Cap'),
                      style: TextStyle(
                        color: isPremiumUser
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF1F9DCC),
                        fontSize: 11,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: autoplayNextEnabled
                    ? const Color(0xFF21A45D).withValues(alpha: 0.15)
                    : context.elevatedBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: autoplayNextEnabled
                      ? const Color(0xFF21A45D)
                      : context.borderCol,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    autoplayNextEnabled
                        ? Icons.skip_next_rounded
                        : Icons.pause_circle_outline_rounded,
                    size: 14,
                    color: autoplayNextEnabled
                        ? const Color(0xFF21A45D)
                        : context.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    autoplayNextEnabled
                        ? 'Autoplay Next: ON'
                        : 'Autoplay Next: OFF',
                    style: TextStyle(
                      color: autoplayNextEnabled
                          ? const Color(0xFF21A45D)
                          : context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.elevatedBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.borderCol),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed_rounded, size: 14, color: context.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    bufferProfile,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          seriesTitle.isEmpty ? 'Series Episode' : seriesTitle,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          'Episode ${episode.episodeNumber}: ${episode.title}',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          episode.description.isEmpty
              ? 'Watch this episode and continue through the season from the list below.'
              : episode.description,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),

        // If autoplay is enabled and there is a next episode, render the interactive next banner
        if (autoplayNextEnabled && nextEpisode != null) ...[
          Container(
            margin: const EdgeInsets.only(top: 20, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF05454).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF05454).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF05454), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AUTOPLAY UP NEXT IN SERIES',
                        style: TextStyle(
                          color: Color(0xFFF05454),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Episode ${nextEpisode.episodeNumber}: ${nextEpisode.title}',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => onEpisodeTap(nextEpisode),
                  icon: const Icon(Icons.skip_next_rounded, size: 16),
                  label: const Text('Play Next Episode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05454),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        Text(
          'Up Next In This Season',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (episodesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (episodesError != null)
          Text(episodesError!, style: TextStyle(color: context.textMuted))
        else
          ...seasonEpisodes.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onEpisodeTap(item),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: item.id == episode.id
                        ? (context.isDark
                            ? const Color(0xFF172233)
                            : const Color(0xFFEFF6FF))
                        : context.surfaceBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.id == episode.id
                          ? const Color(0xFFF05454)
                          : context.borderCol,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.elevatedBg,
                      child: Text(
                        item.episodeNumber.toString(),
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(color: context.textPrimary),
                    ),
                    subtitle: Text(
                      item.description.isEmpty
                          ? 'Open episode'
                          : item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textSecondary),
                    ),
                    trailing: item.id == episode.id
                        ? const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Color(0xFFF05454),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: context.textMuted,
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
