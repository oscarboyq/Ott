import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/series_season_model.dart';
import 'package:video/core/models/series_watch_progress_model.dart';
import 'package:video/core/utils/playback_source_resolver.dart';
import 'package:video/core/providers/series_catalog_provider.dart';
import 'package:video/features/video/presentation/widgets/bunny_web_player.dart';
import 'package:video_player/video_player.dart';

class SeriesDetailsPage extends ConsumerStatefulWidget {
  const SeriesDetailsPage({required this.seriesId, super.key});

  final String seriesId;

  @override
  ConsumerState<SeriesDetailsPage> createState() => _SeriesDetailsPageState();
}

class _SeriesDetailsPageState extends ConsumerState<SeriesDetailsPage> {
  String? _selectedSeasonId;

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(seriesDetailsProvider(widget.seriesId));
    final seasonsAsync = ref.watch(seriesSeasonsProvider(widget.seriesId));
    final progressAsync = ref.watch(seriesProgressProvider(widget.seriesId));

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      body: seriesAsync.when(
        data: (series) {
          if (series == null) {
            return const _SeriesErrorState(message: 'Series not found');
          }

          return seasonsAsync.when(
            data: (seasons) {
              final activeSeason = _resolveSeason(
                seasons: seasons,
                progress: progressAsync.valueOrNull,
              );
              final episodesAsync = activeSeason == null
                  ? const AsyncValue<List<SeriesEpisodeModel>>.data([])
                  : ref.watch(seasonEpisodesProvider(activeSeason.id));

              return episodesAsync.when(
                data: (episodes) => _SeriesDetailsContent(
                  series: series,
                  seasons: seasons,
                  selectedSeason: activeSeason,
                  episodes: episodes,
                  progress: progressAsync.valueOrNull,
                  onSeasonSelected: (season) {
                    setState(() {
                      _selectedSeasonId = season.id;
                    });
                  },
                ),
                loading: () => _SeriesDetailsContent(
                  series: series,
                  seasons: seasons,
                  selectedSeason: activeSeason,
                  episodes: const [],
                  progress: progressAsync.valueOrNull,
                  onSeasonSelected: (season) {
                    setState(() {
                      _selectedSeasonId = season.id;
                    });
                  },
                  episodesLoading: true,
                ),
                error: (_, __) => _SeriesDetailsContent(
                  series: series,
                  seasons: seasons,
                  selectedSeason: activeSeason,
                  episodes: const [],
                  progress: progressAsync.valueOrNull,
                  onSeasonSelected: (season) {
                    setState(() {
                      _selectedSeasonId = season.id;
                    });
                  },
                  episodesError: 'Unable to load episodes',
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const _SeriesErrorState(message: 'Unable to load seasons'),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const _SeriesErrorState(message: 'Unable to load series details'),
      ),
    );
  }

  SeriesSeasonModel? _resolveSeason({
    required List<SeriesSeasonModel> seasons,
    required SeriesWatchProgressModel? progress,
  }) {
    if (seasons.isEmpty) {
      return null;
    }

    if (_selectedSeasonId != null) {
      for (final season in seasons) {
        if (season.id == _selectedSeasonId) {
          return season;
        }
      }
    }

    if (progress != null) {
      for (final season in seasons) {
        if (season.id == progress.seasonId) {
          return season;
        }
      }
    }

    return seasons.first;
  }
}

class _SeriesDetailsContent extends StatelessWidget {
  const _SeriesDetailsContent({
    required this.series,
    required this.seasons,
    required this.selectedSeason,
    required this.episodes,
    required this.progress,
    required this.onSeasonSelected,
    this.episodesLoading = false,
    this.episodesError,
  });

  final SeriesModel series;
  final List<SeriesSeasonModel> seasons;
  final SeriesSeasonModel? selectedSeason;
  final List<SeriesEpisodeModel> episodes;
  final SeriesWatchProgressModel? progress;
  final ValueChanged<SeriesSeasonModel> onSeasonSelected;
  final bool episodesLoading;
  final String? episodesError;

  @override
  Widget build(BuildContext context) {
    final firstEpisode = episodes.isNotEmpty ? episodes.first : null;
    final continueEpisode = progress == null
        ? null
        : episodes
              .where((episode) => episode.id == progress!.episodeId)
              .firstOrNull;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF070B12),
          expandedHeight: 320,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (series.backdropUrl.isNotEmpty)
                  Image.network(
                    series.backdropUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFF101826)),
                  )
                else
                  Container(color: const Color(0xFF101826)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22070B12), Color(0xFF070B12)],
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (series.isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF05454),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'FEATURED SERIES',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        series.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _MetaPill(label: series.genre),
                          _MetaPill(label: '${series.seasonCount} seasons'),
                          _MetaPill(label: '${series.episodeCount} episodes'),
                          _MetaPill(
                            label: series.requiresPremium ? 'Premium' : 'Free',
                            accent: series.requiresPremium
                                ? const Color(0xFFF05454)
                                : const Color(0xFF21A45D),
                          ),
                        ],
                      ),
                      if (series.tagline.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          series.tagline,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (continueEpisode != null)
                      FilledButton.icon(
                        onPressed: () => context.push(
                          '/series/${series.id}/episode/${continueEpisode.id}',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF05454),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          'Continue S${selectedSeason?.seasonNumber ?? 1}:E${continueEpisode.episodeNumber}',
                        ),
                      ),
                    if (continueEpisode == null && firstEpisode != null)
                      FilledButton.icon(
                        onPressed: () => context.push(
                          '/series/${series.id}/episode/${firstEpisode.id}',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF05454),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play Season Start'),
                      ),
                    if ((series.trailerUrl ?? '').isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _showSeriesTrailer(
                          context,
                          title: series.title,
                          trailerUrl: series.trailerUrl!,
                        ),
                        icon: const Icon(Icons.ondemand_video_rounded),
                        label: const Text('Watch Trailer'),
                      ),
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Watchlist Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seasons',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: seasons
                      .map(
                        (season) => ChoiceChip(
                          label: Text(
                            'Season ${season.seasonNumber}',
                            style: TextStyle(
                              color: season.id == selectedSeason?.id
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ),
                          selected: season.id == selectedSeason?.id,
                          selectedColor: const Color(0xFFF05454),
                          backgroundColor: const Color(0xFF162235),
                          onSelected: (_) => onSeasonSelected(season),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Text(
              selectedSeason == null
                  ? 'Episodes'
                  : 'Season ${selectedSeason!.seasonNumber} Episodes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (episodesLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (episodesError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                episodesError!,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          )
        else if (episodes.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No episodes available yet for this season.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList.separated(
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final episode = episodes[index];
                final isInProgress = progress?.episodeId == episode.id;

                return _EpisodeTile(
                  episode: episode,
                  isInProgress: isInProgress,
                  onTap: () => context.push(
                    '/series/${series.id}/episode/${episode.id}',
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
            ),
          ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.onTap,
    this.isInProgress = false,
  });

  final SeriesEpisodeModel episode;
  final VoidCallback onTap;
  final bool isInProgress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: isInProgress
              ? const Color(0xFF172233)
              : const Color(0xFF101826),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isInProgress
                ? const Color(0xFFF05454)
                : const Color(0xFF243247),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 128,
                  height: 72,
                  child: episode.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          episode.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF162235),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.live_tv_rounded,
                              color: Colors.white30,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF162235),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.live_tv_rounded,
                            color: Colors.white30,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Episode ${episode.episodeNumber}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (episode.requiresPremium)
                          const _MetaPill(
                            label: 'Premium',
                            accent: Color(0xFFF05454),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      episode.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      episode.description.isEmpty
                          ? 'Open episode details and playback.'
                          : episode.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white38,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatEpisodeDuration(episode.duration),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isInProgress)
                          const Text(
                            'Continue watching',
                            style: TextStyle(
                              color: Color(0xFFF7A6A6),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatEpisodeDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.accent = const Color(0xFF243247)});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent == const Color(0xFF243247)
              ? Colors.white70
              : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SeriesErrorState extends StatelessWidget {
  const _SeriesErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: Colors.white54)),
    );
  }
}

void _showSeriesTrailer(
  BuildContext context, {
  required String title,
  required String trailerUrl,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFF0D1520),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title Trailer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SeriesTrailerPlayer(videoUrl: trailerUrl),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SeriesTrailerPlayer extends StatefulWidget {
  const _SeriesTrailerPlayer({required this.videoUrl});

  final String videoUrl;

  @override
  State<_SeriesTrailerPlayer> createState() => _SeriesTrailerPlayerState();
}

class _SeriesTrailerPlayerState extends State<_SeriesTrailerPlayer> {
  VideoPlayerController? _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && isBunnyStreamUrl(widget.videoUrl)) {
      return;
    }

    final resolvedUrl = resolvePlayableVideoUrl(widget.videoUrl);
    final controller = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
    _controller = controller;
    unawaited(
      controller
          .initialize()
          .then((_) async {
            await controller.play();
            if (mounted) {
              setState(() {});
            }
          })
          .catchError((Object _) {
            if (!mounted) {
              return;
            }

            setState(() {
              _errorMessage = 'Trailer could not be played on this device.';
            });
          }),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && isBunnyStreamUrl(widget.videoUrl)) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BunnyWebPlayer(videoUrl: widget.videoUrl),
        ),
      );
    }

    final controller = _controller;
    final isReady = controller?.value.isInitialized ?? false;

    return AspectRatio(
      aspectRatio: isReady ? controller!.value.aspectRatio : 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: const Color(0xFF101826),
          child: _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : isReady
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller!),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        onPressed: () {
                          if (controller.value.isPlaying) {
                            controller.pause();
                          } else {
                            controller.play();
                          }
                          setState(() {});
                        },
                        backgroundColor: const Color(0xFFF05454),
                        child: Icon(
                          controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF05454)),
                ),
        ),
      ),
    );
  }
}
