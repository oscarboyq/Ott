import 'package:flutter_test/flutter_test.dart';
import 'package:video/core/utils/playback_source_resolver.dart';

void main() {
  group('playback_source_resolver tests', () {
    test('parseResolutionNumeric extracts correct integer resolution', () {
      expect(parseResolutionNumeric('480p SD'), 480);
      expect(parseResolutionNumeric('720p HD'), 720);
      expect(parseResolutionNumeric('1080p Full HD'), 1080);
      expect(parseResolutionNumeric('4K Ultra HD'), 2160);
      expect(parseResolutionNumeric('360p Low'), 360);
      expect(parseResolutionNumeric('240p Saver'), 240);
      expect(parseResolutionNumeric('Auto (Adaptive Bitrate)'), isNull);
      expect(parseResolutionNumeric(''), isNull);
      expect(parseResolutionNumeric(null), isNull);
    });

    test('extractBunnyVideoGuid extracts GUID correctly', () {
      const guid = '4f2a71bf-1049-43c2-b918-a83d47ad47f9';
      expect(
        extractBunnyVideoGuid(
          videoUrl: 'https://iframe.mediadelivery.net/embed/399081/$guid',
          providerVideoId: null,
        ),
        guid,
      );
      expect(
        extractBunnyVideoGuid(
          videoUrl: 'https://vz-399081.b-cdn.net/$guid/playlist.m3u8',
          providerVideoId: null,
        ),
        guid,
      );
      expect(
        extractBunnyVideoGuid(
          videoUrl: 'https://example.com/stream',
          providerVideoId: guid,
        ),
        guid,
      );
    });

    test('extractBunnyPullZoneHost handles configured or inferred hosts', () {
      expect(
        extractBunnyPullZoneHost(
          videoUrl: 'https://iframe.mediadelivery.net/embed/399081/video-id',
          libraryId: '399081',
          configuredPullZone: 'vz-399081.b-cdn.net',
        ),
        'vz-399081.b-cdn.net',
      );
      expect(
        extractBunnyPullZoneHost(
          videoUrl: 'https://iframe.mediadelivery.net/embed/399081/video-id',
          libraryId: '399081',
          configuredPullZone: '',
        ),
        'vz-399081.b-cdn.net',
      );
    });

    test('resolveTierCappedBunnyMediaUrl generates direct MP4 url for capped tiers', () {
      const guid = '4f2a71bf-1049-43c2-b918-a83d47ad47f9';
      final url480 = resolveTierCappedBunnyMediaUrl(
        videoUrl: 'https://iframe.mediadelivery.net/embed/399081/$guid',
        providerVideoId: guid,
        libraryId: '399081',
        configuredPullZone: 'vz-399081.b-cdn.net',
        quality: '480p SD',
      );
      expect(
        url480,
        'https://vz-399081.b-cdn.net/$guid/play_480p.mp4',
      );

      final url720 = resolveTierCappedBunnyMediaUrl(
        videoUrl: 'https://iframe.mediadelivery.net/embed/399081/$guid',
        providerVideoId: guid,
        libraryId: '399081',
        configuredPullZone: 'vz-399081.b-cdn.net',
        quality: '720p HD',
      );
      expect(
        url720,
        'https://vz-399081.b-cdn.net/$guid/play_720p.mp4',
      );

      final urlAuto = resolveTierCappedBunnyMediaUrl(
        videoUrl: 'https://iframe.mediadelivery.net/embed/399081/$guid',
        providerVideoId: guid,
        libraryId: '399081',
        configuredPullZone: 'vz-399081.b-cdn.net',
        quality: 'Auto (Adaptive Bitrate)',
      );
      expect(urlAuto, isNull);
    });

    test('getQualityOptionsForTier locks qualities exceeding free tier cap', () {
      // Free user with 480p cap
      final options480 = getQualityOptionsForTier(
        isPremium: false,
        maxQuality: '480p SD',
      );
      expect(options480.firstWhere((o) => o.numeric == 480).isLocked, isFalse);
      expect(options480.firstWhere((o) => o.numeric == 360).isLocked, isFalse);
      expect(options480.firstWhere((o) => o.numeric == 240).isLocked, isFalse);
      expect(options480.firstWhere((o) => o.numeric == 720).isLocked, isTrue);
      expect(options480.firstWhere((o) => o.numeric == 1080).isLocked, isTrue);
      expect(options480.firstWhere((o) => o.numeric == 2160).isLocked, isTrue);

      // Free user when admin grants 720p permission
      final options720 = getQualityOptionsForTier(
        isPremium: false,
        maxQuality: '720p HD',
      );
      expect(options720.firstWhere((o) => o.numeric == 720).isLocked, isFalse);
      expect(options720.firstWhere((o) => o.numeric == 480).isLocked, isFalse);
      expect(options720.firstWhere((o) => o.numeric == 1080).isLocked, isTrue);
      expect(options720.firstWhere((o) => o.numeric == 2160).isLocked, isTrue);

      // VIP user has all unlocked
      final optionsVip = getQualityOptionsForTier(
        isPremium: true,
        maxQuality: '480p SD',
      );
      for (final opt in optionsVip) {
        expect(opt.isLocked, isFalse);
      }
    });
  });
}
