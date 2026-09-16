import 'package:flutter/material.dart';

class BunnyWebPlayer extends StatelessWidget {
  const BunnyWebPlayer({
    required this.videoUrl,
    this.libraryId,
    this.capturePointerEvents = true,
    this.muted = false,
    this.autoplay = false,
    this.bufferProfile,
    this.preload,
    this.streamQuality,
    this.initialPositionSeconds,
    this.onPositionChanged,
    super.key,
  });

  final String videoUrl;
  final String? libraryId;
  final bool capturePointerEvents;
  final bool muted;
  final bool autoplay;
  final String? bufferProfile;
  final bool? preload;
  final String? streamQuality;
  final int? initialPositionSeconds;
  final ValueChanged<int>? onPositionChanged;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Web-only Bunny player is unavailable on this platform.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
