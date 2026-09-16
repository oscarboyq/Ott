import 'package:flutter/material.dart';

class NetworkWebVideoPlayer extends StatelessWidget {
  const NetworkWebVideoPlayer({
    required this.videoUrl,
    this.muted = false,
    this.autoplay = false,
    this.showControls = true,
    this.loop = false,
    this.bufferProfile,
    this.preload,
    this.initialPositionSeconds,
    this.onPositionChanged,
    super.key,
  });

  final String videoUrl;
  final bool muted;
  final bool autoplay;
  final bool showControls;
  final bool loop;
  final String? bufferProfile;
  final bool? preload;
  final int? initialPositionSeconds;
  final ValueChanged<int>? onPositionChanged;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Web video player is unavailable on this platform.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
