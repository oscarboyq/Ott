class BunnyUploadSession {
  const BunnyUploadSession({
    required this.videoId,
    required this.libraryId,
    required this.uploadUrl,
    required this.playbackUrl,
    required this.embedUrl,
    required this.signature,
    required this.expirationTime,
  });

  final String videoId;
  final String libraryId;
  final String uploadUrl;
  final String playbackUrl;
  final String embedUrl;
  final String signature;
  final int expirationTime;

  factory BunnyUploadSession.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing Bunny upload-session field: $key');
      }
      return value.trim();
    }

    final expiration = json['expirationTime'];
    if (expiration is! num) {
      throw const FormatException(
        'Missing Bunny upload-session field: expirationTime',
      );
    }

    return BunnyUploadSession(
      videoId: requiredString('videoId'),
      libraryId: requiredString('libraryId'),
      uploadUrl: requiredString('uploadUrl'),
      playbackUrl: requiredString('playbackUrl'),
      embedUrl: requiredString('embedUrl'),
      signature: requiredString('signature'),
      expirationTime: expiration.toInt(),
    );
  }
}
