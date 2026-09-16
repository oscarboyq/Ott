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

int? parseResolutionNumeric(String? quality) {
  if (quality == null || quality.trim().isEmpty) return null;
  final q = quality.toLowerCase();
  if (q.contains('auto')) return null;
  if (q.contains('4k') || q.contains('2160')) return 2160;
  if (q.contains('1080')) return 1080;
  if (q.contains('720')) return 720;
  if (q.contains('480')) return 480;
  if (q.contains('360')) return 360;
  if (q.contains('240')) return 240;
  final numMatch = RegExp(r'(\d+)p?').firstMatch(q);
  if (numMatch != null) {
    return int.tryParse(numMatch.group(1)!);
  }
  return null;
}

String? extractBunnyVideoGuid({
  required String videoUrl,
  String? providerVideoId,
}) {
  if (providerVideoId != null && providerVideoId.trim().isNotEmpty) {
    return providerVideoId.trim();
  }
  final uuidRegex = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  final match = uuidRegex.firstMatch(videoUrl);
  if (match != null) {
    return match.group(0);
  }
  final uri = Uri.tryParse(videoUrl.trim());
  if (uri != null && uri.pathSegments.isNotEmpty) {
    for (final seg in uri.pathSegments) {
      if (uuidRegex.hasMatch(seg)) {
        return seg;
      }
    }
  }
  return null;
}

String? extractBunnyPullZoneHost({
  required String videoUrl,
  String? libraryId,
  String? configuredPullZone,
}) {
  if (configuredPullZone != null && configuredPullZone.trim().isNotEmpty) {
    final cleaned = configuredPullZone
        .trim()
        .replaceAll(RegExp(r'^https?:\/\/'), '')
        .replaceAll(RegExp(r'\/.*$'), '');
    if (cleaned.isNotEmpty) return cleaned;
  }
  final uri = Uri.tryParse(videoUrl.trim());
  if (uri != null) {
    final host = uri.host.toLowerCase();
    if (host.contains('b-cdn.net') && !host.contains('mediadelivery.net')) {
      return host;
    }
  }
  if (libraryId != null && libraryId.trim().isNotEmpty) {
    return 'vz-${libraryId.trim()}.b-cdn.net';
  }
  if (uri != null) {
    final embedMatch = RegExp(r'\/embed\/(\d+)\/').firstMatch(uri.path);
    if (embedMatch != null) {
      return 'vz-${embedMatch.group(1)}.b-cdn.net';
    }
  }
  return null;
}

String? resolveTierCappedBunnyMediaUrl({
  required String videoUrl,
  String? providerVideoId,
  String? libraryId,
  String? configuredPullZone,
  required String quality,
}) {
  final numeric = parseResolutionNumeric(quality);
  if (numeric == null) {
    return null;
  }
  final guid = extractBunnyVideoGuid(
    videoUrl: videoUrl,
    providerVideoId: providerVideoId,
  );
  if (guid == null || guid.isEmpty) {
    return null;
  }
  final host = extractBunnyPullZoneHost(
    videoUrl: videoUrl,
    libraryId: libraryId,
    configuredPullZone: configuredPullZone,
  );
  if (host == null || host.isEmpty) {
    return null;
  }
  return 'https://$host/$guid/play_${numeric}p.mp4';
}

class QualityOption {
  const QualityOption({
    required this.label,
    required this.numeric,
    required this.isLocked,
  });

  final String label;
  final int numeric;
  final bool isLocked;
}

List<QualityOption> getQualityOptionsForTier({
  required bool isPremium,
  required String maxQuality,
}) {
  final maxNumeric =
      isPremium ? 2160 : (parseResolutionNumeric(maxQuality) ?? 720);

  const allProfiles = [
    (label: '4K Ultra HD', numeric: 2160),
    (label: '1080p Full HD', numeric: 1080),
    (label: '720p HD', numeric: 720),
    (label: '480p SD', numeric: 480),
    (label: '360p Low', numeric: 360),
    (label: '240p Saver', numeric: 240),
  ];

  return allProfiles.map((p) {
    final isLocked = !isPremium && p.numeric > maxNumeric;
    return QualityOption(
      label: p.label,
      numeric: p.numeric,
      isLocked: isLocked,
    );
  }).toList();
}

