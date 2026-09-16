import 'package:flutter_test/flutter_test.dart';
import 'package:video/core/models/auth_response_model.dart';
import 'package:video/core/models/series_episode_model.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/series_season_model.dart';
import 'package:video/core/models/series_watch_progress_model.dart';
import 'package:video/core/models/user_model.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/utils/safe_type_parsers.dart';

void main() {
  group('safe_type_parsers', () {
    test('parseIntSafe handles ints, doubles, strings, and defaults', () {
      expect(parseIntSafe(42), 42);
      expect(parseIntSafe(42.9), 42);
      expect(parseIntSafe('100'), 100);
      expect(parseIntSafe('invalid', 5), 5);
      expect(parseIntSafe(null, 7), 7);
    });

    test('parseDoubleSafe handles doubles, ints, strings, and defaults', () {
      expect(parseDoubleSafe(3.14), 3.14);
      expect(parseDoubleSafe(42), 42.0);
      expect(parseDoubleSafe('2.718'), 2.718);
      expect(parseDoubleSafe('invalid', 1.0), 1.0);
      expect(parseDoubleSafe(null, 0.5), 0.5);
    });

    test('parseBoolSafe handles booleans, strings, and numbers', () {
      expect(parseBoolSafe(true), true);
      expect(parseBoolSafe(false), false);
      expect(parseBoolSafe('true'), true);
      expect(parseBoolSafe('TRUE'), true);
      expect(parseBoolSafe('1'), true);
      expect(parseBoolSafe(1), true);
      expect(parseBoolSafe('false'), false);
      expect(parseBoolSafe('0'), false);
      expect(parseBoolSafe(0), false);
      expect(parseBoolSafe(null, true), true);
      expect(parseBoolSafe(null, false), false);
    });

    test('parseDateTimeSafe handles valid strings, nulls, and fallbacks', () {
      final now = DateTime.now();
      expect(parseDateTimeSafe(now.toIso8601String()).year, now.year);
      final fallback = DateTime(2020, 1, 1);
      expect(parseDateTimeSafe('invalid', fallback), fallback);
      expect(parseDateTimeSafe(null, fallback), fallback);
    });

    test('parseDateTimeNullableSafe handles valid strings and null/invalid', () {
      final now = DateTime.now();
      expect(parseDateTimeNullableSafe(now.toIso8601String())?.year, now.year);
      expect(parseDateTimeNullableSafe('invalid'), isNull);
      expect(parseDateTimeNullableSafe(null), isNull);
    });

    test('parseStringListSafe handles lists of various types', () {
      expect(parseStringListSafe(['a', 'b', 'c']), ['a', 'b', 'c']);
      expect(parseStringListSafe(['a', 123, null]), ['a', '123']);
      expect(parseStringListSafe(null), isEmpty);
    });
  });

  group('Model Deserialization Resilience', () {
    test('UserModel.fromJson deserializes safely with dynamic keys and types', () {
      final rawUser = {
        'id': 'user-123',
        'email': 'user@example.com',
        'username': 'testuser',
        'is_admin': 0,
        'is_premium': false,
        'created_at': '2025-01-01T00:00:00.000Z',
      };

      final user = UserModel.fromJson(rawUser);
      expect(user.id, 'user-123');
      expect(user.email, 'user@example.com');
      expect(user.username, 'testuser');
      expect(user.isAdmin, false);
      expect(user.isPremium, false);
    });

    test('VideoModel.fromJson handles double duration, string counts, and missing qualities', () {
      final rawVideo = {
        'id': 'vid-1',
        'title': 'Test Video',
        'description': 'Description',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'video_url': 'https://example.com/video.mp4',
        'category': 'Action',
        'rating': 4.5,
        'rating_count': 10.0, // double instead of int
        'duration_seconds': 120.0, // double instead of int
        'views_count': '350', // string instead of int
        'is_free': true,
        'created_at': '2025-01-01T00:00:00.000Z',
      };

      final video = VideoModel.fromJson(rawVideo);
      expect(video.id, 'vid-1');
      expect(video.ratingCount, 10);
      expect(video.duration, 120);
      expect(video.viewCount, 350);
      expect(video.requiresPremium, false);
    });

    test('SeriesModel.fromJson handles dynamic numbers and null fields safely', () {
      final rawSeries = {
        'id': 'series-1',
        'title': 'Test Series',
        'description': 'A great series',
        'thumbnail_url': 'https://example.com/series.jpg',
        'category': 'Drama',
        'rating': 4.8,
        'rating_count': 50,
        'season_count': 2.0,
        'episode_count': 24.0,
        'created_at': '2025-01-01T00:00:00.000Z',
      };

      final series = SeriesModel.fromJson(rawSeries);
      expect(series.id, 'series-1');
      expect(series.title, 'Test Series');
      expect(series.seasonCount, 2);
      expect(series.episodeCount, 24);
    });

    test('SeriesSeasonModel and SeriesEpisodeModel parse safely', () {
      final rawSeason = {
        'id': 's1',
        'series_id': 'series-1',
        'season_number': 1.0,
        'title': 'Season 1',
        'created_at': '2025-01-01T00:00:00.000Z',
      };
      final season = SeriesSeasonModel.fromJson(rawSeason);
      expect(season.id, 's1');
      expect(season.seasonNumber, 1);

      final rawEpisode = {
        'id': 'ep1',
        'series_id': 'series-1',
        'season_id': 's1',
        'episode_number': 1.0,
        'title': 'Pilot',
        'duration': 2400.0,
        'created_at': '2025-01-01T00:00:00.000Z',
      };
      final episode = SeriesEpisodeModel.fromJson(rawEpisode);
      expect(episode.id, 'ep1');
      expect(episode.episodeNumber, 1);
      expect(episode.duration, 2400);
    });

    test('SeriesWatchProgressModel parses safely', () {
      final rawProgress = {
        'id': 'prog-1',
        'user_id': 'user-123',
        'series_id': 'series-1',
        'season_id': 's1',
        'episode_id': 'ep1',
        'position_seconds': 500.0,
        'is_completed': 1,
        'last_watched_at': '2025-01-01T00:00:00.000Z',
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };
      final progress = SeriesWatchProgressModel.fromJson(rawProgress);
      expect(progress.id, 'prog-1');
      expect(progress.positionSeconds, 500);
      expect(progress.isCompleted, true);
    });

    test('AuthResponseModel parses safely with nested user dynamic map', () {
      final rawAuth = {
        'access_token': 'token-123',
        'refresh_token': 'refresh-456',
        'user': {
          'id': 'user-123',
          'email': 'user@example.com',
          'username': 'testuser',
          'is_admin': false,
          'is_premium': false,
          'created_at': '2025-01-01T00:00:00.000Z',
        },
      };
      final auth = AuthResponseModel.fromJson(rawAuth);
      expect(auth.accessToken, 'token-123');
      expect(auth.refreshToken, 'refresh-456');
      expect(auth.user.id, 'user-123');
    });
  });
}
