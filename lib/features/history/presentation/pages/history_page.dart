import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/models/series_history_item_model.dart';
import 'package:video/core/models/watch_history_item_model.dart';
import 'package:video/core/providers/watch_history_provider.dart';

String _formatPlaybackTime(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  return '${duration.inMinutes}:${remainingSeconds.toString().padLeft(2, '0')}';
}

class _HistoryFeedEntry {
  _HistoryFeedEntry.video(this.videoItem)
    : seriesItem = null,
      watchedAt = videoItem!.watchedAt;

  _HistoryFeedEntry.series(this.seriesItem)
    : videoItem = null,
      watchedAt = seriesItem!.lastWatchedAt;

  final WatchHistoryItemModel? videoItem;
  final SeriesHistoryItemModel? seriesItem;
  final DateTime watchedAt;

  bool get isVideo => videoItem != null;
}

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchHistoryProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(watchHistoryProvider);
    final seriesHistoryAsync = ref.watch(seriesHistoryProvider);
    final historyItems = historyState.items;
    final seriesHistoryItems =
        seriesHistoryAsync.valueOrNull ?? const <SeriesHistoryItemModel>[];
    final combinedItems = <_HistoryFeedEntry>[
      ...historyItems.map(_HistoryFeedEntry.video),
      ...seriesHistoryItems.map(_HistoryFeedEntry.series),
    ]..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    final isHistoryLoading =
        historyState.isLoading || seriesHistoryAsync.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: const Color(0xFF070B12),
      ),
      body: isHistoryLoading
          ? const Center(child: CircularProgressIndicator())
          : combinedItems.isEmpty
          ? _HistoryEmptyState(onBrowseVideos: () => context.go('/'))
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(watchHistoryProvider.notifier).loadHistory();
                ref.invalidate(seriesHistoryProvider);
                await ref.read(seriesHistoryProvider.future);
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: combinedItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = combinedItems[index];
                  if (item.videoItem != null) {
                    final videoItem = item.videoItem!;
                    return _VideoHistoryListCard(
                      item: videoItem,
                      onTap: () => context.push('/video/${videoItem.videoId}'),
                    );
                  }

                  final seriesItem = item.seriesItem!;
                  return _SeriesHistoryListCard(
                    item: seriesItem,
                    onTap: () => context.push(
                      '/series/${seriesItem.seriesId}/episode/${seriesItem.episodeId}',
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.onBrowseVideos});

  final VoidCallback onBrowseVideos;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF101826),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Colors.white70,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No history yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Videos, reels, and series episodes you start watching will appear here with resume progress.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onBrowseVideos,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Browse Videos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoHistoryListCard extends StatelessWidget {
  const _VideoHistoryListCard({required this.item, required this.onTap});

  final WatchHistoryItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF101826),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF243247)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 126,
                  height: 78,
                  child: Image.network(
                    item.video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF162235),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.movie_outlined,
                        color: Colors.white24,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.hasResumePosition
                          ? 'Resume from ${_formatPlaybackTime(item.durationWatchedSeconds)}'
                          : 'Watched to the end. Start again anytime.',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF243247),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFF05454),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatPlaybackTime(item.durationWatchedSeconds)} of ${_formatPlaybackTime(item.video.duration)} watched',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
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
}

class _SeriesHistoryListCard extends StatelessWidget {
  const _SeriesHistoryListCard({required this.item, required this.onTap});

  final SeriesHistoryItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = item.episode.thumbnailUrl.isNotEmpty
        ? item.episode.thumbnailUrl
        : item.series.posterUrl;
    final resumeLabel = item.hasResumePosition
        ? 'Resume episode from ${_formatPlaybackTime(item.positionSeconds)}'
        : item.isCompleted
        ? 'Episode completed. Watch again anytime.'
        : 'Episode opened recently.';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF101826),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF243247)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 126,
                  height: 78,
                  child: Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF162235),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.tv_rounded,
                        color: Colors.white24,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.series.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Episode ${item.episode.episodeNumber}: ${item.episode.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      resumeLabel,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF243247),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1F9DCC),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatPlaybackTime(item.positionSeconds)} of ${_formatPlaybackTime(item.episode.duration)} watched',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
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
}
