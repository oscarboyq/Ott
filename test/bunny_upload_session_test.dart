import 'package:flutter_test/flutter_test.dart';
import 'package:video/core/models/bunny_upload_session.dart';

void main() {
  test('parses a complete Bunny upload session', () {
    final session = BunnyUploadSession.fromJson({
      'videoId': 'video-guid',
      'libraryId': '123456',
      'uploadUrl': 'https://video.bunnycdn.com/tusupload',
      'playbackUrl': 'https://vz-example.b-cdn.net/video-guid/playlist.m3u8',
      'embedUrl': 'https://iframe.mediadelivery.net/embed/123456/video-guid',
      'signature': 'signed-value',
      'expirationTime': 1780000000,
    });

    expect(session.videoId, 'video-guid');
    expect(session.libraryId, '123456');
    expect(session.expirationTime, 1780000000);
  });

  test('rejects an incomplete Bunny upload session', () {
    expect(
      () => BunnyUploadSession.fromJson(const {}),
      throwsA(isA<FormatException>()),
    );
  });
}
