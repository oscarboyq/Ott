import 'package:flutter/foundation.dart';

const String _webSafeSampleVideoUrl =
    'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

bool isBunnyStreamUrl(String videoUrl) {
  final uri = Uri.tryParse(videoUrl);
  if (uri == null) {
    return false;
  }

  return uri.host.contains('mediadelivery.net') ||
      uri.host.contains('b-cdn.net') ||
      videoUrl.contains('/playlist.m3u8');
}

String resolvePlayableVideoUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null || !kIsWeb) {
    return rawUrl;
  }

  final pathSegments = uri.pathSegments;
  final isGoogleSampleVideo =
      uri.host == 'storage.googleapis.com' &&
      pathSegments.length >= 3 &&
      pathSegments[0] == 'gtv-videos-bucket' &&
      pathSegments[1] == 'sample';

  if (!isGoogleSampleVideo) {
    return rawUrl;
  }

  if (pathSegments.last.toLowerCase() == 'bigbuckbunny.mp4') {
    return rawUrl;
  }

  return _webSafeSampleVideoUrl;
}
