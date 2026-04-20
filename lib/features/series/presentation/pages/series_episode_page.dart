import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/providers/series_catalog_provider.dart';
import 'package:video/core/providers/watch_history_provider.dart';
import 'package:video/core/utils/playback_source_resolver.dart';
import 'package:video/features/video/presentation/widgets/bunny_web_player.dart';
import 'package:video/features/video/presentation/widgets/network_web_video_player.dart';
import 'package:video_player/video_player.dart';

class SeriesEpisodePage extends ConsumerStatefulWidget {
  const SeriesEpisodePage({
    required this.seriesId,
    required this.episodeId,
    super.key,
  });

  final String seriesId;
  final String episodeId;

  @override
  ConsumerState<SeriesEpisodePage> createState() => _SeriesEpisodePageState();
}

class _SeriesEpisodePageState extends ConsumerState<SeriesEpisodePage> {
  VideoPlayerController? _controller;
  String? _activeEpisodeId;
  SeriesEpisodeModel? _activeEpisode;
  String? _historySeededEpisodeId;
  String? _playerError;
  int _lastSavedPosition = -1;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    unawaited(_persistProgress(force: true));
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

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B12),
        title: Text(seriesAsync.valueOrNull?.title ?? 'Episode'),
      ),
      body: episodeAsync.when(
        data: (episode) {
          if (episode == null) {
            return const Center(
              child: Text(
                'Episode not found',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final series = seriesAsync.valueOrNull;
          _ensureController(episode);
          if (series != null) {
            _ensureHistorySeeded(series: series, episode: episode);
          }
          final seasonEpisodesAsync = ref.watch(
            seasonEpisodesProvider(episode.seasonId),
          );

          return seasonEpisodesAsync.when(
            data: (seasonEpisodes) => _EpisodePageContent(
              episode: episode,
              seriesTitle: seriesAsync.valueOrNull?.title ?? '',
              controller: _controller,
              playerError: _playerError,
              onPlayPause: _togglePlayback,
              seasonEpisodes: seasonEpisodes,
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
              onEpisodeTap: (_) {},
            ),
            error: (_, __) => _EpisodePageContent(
              episode: episode,
              seriesTitle: seriesAsync.valueOrNull?.title ?? '',
              controller: _controller,
              playerError: _playerError,
              onPlayPause: _togglePlayback,
              seasonEpisodes: const [],
              episodesError: 'Unable to load season episodes',
              onEpisodeTap: (_) {},
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text(
            'Unable to load episode',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ),
    );
  }

  void _ensureController(SeriesEpisodeModel episode) {
    if (_activeEpisodeId == episode.id && _controller != null) {
      return;
    }

    unawaited(_persistProgress(force: true));
    _controller?.removeListener(_handlePlaybackChanged);
    _controller?.dispose();

    _activeEpisodeId = episode.id;
    _activeEpisode = episode;
    _playerError = null;
    _lastSavedPosition = -1;

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

    try {
      final series = ref
          .read(seriesDetailsProvider(widget.seriesId))
          .valueOrNull;
      if (series == null) {
        return;
      }

      await ref
          .read(watchHistoryProvider.notifier)
          .recordSeriesPlayback(
            series: series,
            episode: episode,
            watchedSeconds: position,
          );
    } catch (_) {
      // Ignore guest or transient save failures for now.
    }
  }

  void _ensureHistorySeeded({
    required SeriesModel series,
    required SeriesEpisodeModel episode,
  }) {
    if (_historySeededEpisodeId == episode.id) {
      return;
    }

    _historySeededEpisodeId = episode.id;
    unawaited(
      ref
          .read(watchHistoryProvider.notifier)
          .recordSeriesPlayback(
            series: series,
            episode: episode,
            watchedSeconds: 0,
          ),
    );
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
    this.episodesLoading = false,
    this.episodesError,
  });

  final SeriesEpisodeModel episode;
  final String seriesTitle;
  final VideoPlayerController? controller;
  final String? playerError;
  final VoidCallback onPlayPause;
  final List<SeriesEpisodeModel> seasonEpisodes;
  final ValueChanged<SeriesEpisodeModel> onEpisodeTap;
  final bool episodesLoading;
  final String? episodesError;

  @override
  Widget build(BuildContext context) {
    final videoValue = controller?.value;
    final isReady = videoValue?.isInitialized ?? false;
    final resolvedVideoUrl = resolvePlayableVideoUrl(episode.videoUrl);
    final useWebVideoSurface = kIsWeb;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        AspectRatio(
          aspectRatio: isReady ? videoValue!.aspectRatio : 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: const Color(0xFF101826),
              child: useWebVideoSurface
                  ? (isBunnyStreamUrl(episode.videoUrl)
                        ? BunnyWebPlayer(videoUrl: episode.videoUrl)
                        : NetworkWebVideoPlayer(videoUrl: resolvedVideoUrl))
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
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.white54,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            playerError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
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
        Text(
          seriesTitle.isEmpty ? 'Series Episode' : seriesTitle,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          'Episode ${episode.episodeNumber}: ${episode.title}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          episode.description.isEmpty
              ? 'Watch this episode and continue through the season from the list below.'
              : episode.description,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Up Next In This Season',
          style: TextStyle(
            color: Colors.white,
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
          Text(episodesError!, style: const TextStyle(color: Colors.white54))
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
                        ? const Color(0xFF172233)
                        : const Color(0xFF101826),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.id == episode.id
                          ? const Color(0xFFF05454)
                          : const Color(0xFF243247),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF162235),
                      child: Text(
                        item.episodeNumber.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      item.description.isEmpty
                          ? 'Open episode'
                          : item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: item.id == episode.id
                        ? const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Color(0xFFF05454),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white54,
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
