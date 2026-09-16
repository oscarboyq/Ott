import 'package:flutter_test/flutter_test.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/models/series_history_item_model.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/models/watch_history_item_model.dart';

void main() {
  group('Continue Watching and Playback Resume Tests', () {
    final now = DateTime.now();

    final testVideo = VideoModel(
      id: 'vid-123',
      title: 'Inception',
      description: 'A mind-bending thriller',
      videoUrl: 'https://vz-123.b-cdn.net/guid/play_720p.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      genre: 'Sci-Fi',
      rating: 4.8,
      ratingCount: 120,
      duration: 7200,
      viewCount: 1000,
      requiresPremium: false,
      releaseDate: now,
      createdAt: now,
    );

    final testSeries = SeriesModel(
      id: 'series-456',
      title: 'Stranger Things',
      description: 'Mysteries in Hawkins',
      posterUrl: 'https://example.com/poster.jpg',
      backdropUrl: 'https://example.com/backdrop.jpg',
      tagline: 'One summer can change everything',
      genre: 'Drama',
      seasonCount: 1,
      episodeCount: 8,
      releaseDate: now,
      createdAt: now,
      updatedAt: now,
    );

    final testEpisode = SeriesEpisodeModel(
      id: 'ep-789',
      seriesId: 'series-456',
      seasonId: 'season-1',
      episodeNumber: 1,
      title: 'Chapter One',
      description: 'The Vanishing of Will Byers',
      thumbnailUrl: 'https://example.com/ep1.jpg',
      videoUrl: 'https://vz-123.b-cdn.net/guid-ep1/playlist.m3u8',
      duration: 3000,
      createdAt: now,
      updatedAt: now,
    );

    test('WatchHistoryItemModel correctly identifies resume position', () {
      final itemZero = WatchHistoryItemModel(
        id: 'hist-1',
        videoId: testVideo.id,
        watchedAt: now,
        durationWatchedSeconds: 0,
        video: testVideo,
      );
      expect(itemZero.hasResumePosition, isFalse);

      final itemMidway = WatchHistoryItemModel(
        id: 'hist-2',
        videoId: testVideo.id,
        watchedAt: now,
        durationWatchedSeconds: 1500,
        video: testVideo,
      );
      expect(itemMidway.hasResumePosition, isTrue);

      final itemCompleted = WatchHistoryItemModel(
        id: 'hist-3',
        videoId: testVideo.id,
        watchedAt: now,
        durationWatchedSeconds: 7200,
        video: testVideo,
      );
      expect(itemCompleted.hasResumePosition, isFalse);
    });

    test('SeriesHistoryItemModel correctly identifies resume position', () {
      final itemZero = SeriesHistoryItemModel(
        id: 'shist-1',
        userId: 'user-1',
        seriesId: testSeries.id,
        seasonId: testEpisode.seasonId,
        episodeId: testEpisode.id,
        positionSeconds: 0,
        isCompleted: false,
        lastWatchedAt: now,
        series: testSeries,
        episode: testEpisode,
      );
      expect(itemZero.hasResumePosition, isFalse);

      final itemMidway = SeriesHistoryItemModel(
        id: 'shist-2',
        userId: 'user-1',
        seriesId: testSeries.id,
        seasonId: testEpisode.seasonId,
        episodeId: testEpisode.id,
        positionSeconds: 840,
        isCompleted: false,
        lastWatchedAt: now,
        series: testSeries,
        episode: testEpisode,
      );
      expect(itemMidway.hasResumePosition, isTrue);

      final itemCompleted = SeriesHistoryItemModel(
        id: 'shist-3',
        userId: 'user-1',
        seriesId: testSeries.id,
        seasonId: testEpisode.seasonId,
        episodeId: testEpisode.id,
        positionSeconds: 3000,
        isCompleted: true,
        lastWatchedAt: now,
        series: testSeries,
        episode: testEpisode,
      );
      expect(itemCompleted.hasResumePosition, isFalse);
    });

    test('Route start query parameter parsing works seamlessly', () {
      final uriWithStart = Uri.parse('/video/vid-123?start=1500');
      final startSeconds = int.tryParse(uriWithStart.queryParameters['start'] ?? '');
      expect(startSeconds, 1500);

      final uriWithoutStart = Uri.parse('/video/vid-123');
      final nullSeconds = int.tryParse(uriWithoutStart.queryParameters['start'] ?? '');
      expect(nullSeconds, isNull);

      final epUriWithStart = Uri.parse('/series/s-1/episode/ep-1?start=420');
      final epStart = int.tryParse(epUriWithStart.queryParameters['start'] ?? '');
      expect(epStart, 420);
    });

    test('Video with duration 0 or unknown still retains resume position when watched', () {
      final videoZeroDuration = VideoModel(
        id: 'vid-zero-dur',
        title: 'Livestream or Unknown Duration Video',
        description: 'No explicit duration',
        videoUrl: 'https://example.com/live.m3u8',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        genre: 'Live',
        rating: 5.0,
        ratingCount: 10,
        duration: 0,
        viewCount: 50,
        requiresPremium: false,
        releaseDate: now,
        createdAt: now,
      );

      final item = WatchHistoryItemModel(
        id: 'hist-zd',
        videoId: videoZeroDuration.id,
        watchedAt: now,
        durationWatchedSeconds: 120,
        video: videoZeroDuration,
      );

      expect(item.hasResumePosition, isTrue);
    });

    test('Series episode with duration 0 or unknown still retains resume position when watched', () {
      final epZeroDuration = SeriesEpisodeModel(
        id: 'ep-zero-dur',
        seriesId: testSeries.id,
        seasonId: 'season-1',
        episodeNumber: 2,
        title: 'Special Live Episode',
        description: 'Special',
        thumbnailUrl: 'https://example.com/ep2.jpg',
        videoUrl: 'https://example.com/ep2.m3u8',
        duration: 0,
        createdAt: now,
        updatedAt: now,
      );

      final item = SeriesHistoryItemModel(
        id: 'shist-zd',
        userId: 'user-1',
        seriesId: testSeries.id,
        seasonId: epZeroDuration.seasonId,
        episodeId: epZeroDuration.id,
        positionSeconds: 240,
        isCompleted: false,
        lastWatchedAt: now,
        series: testSeries,
        episode: epZeroDuration,
      );

      expect(item.hasResumePosition, isTrue);
    });
  });
}
