import 'package:flutter/material.dart';

class NetworkWebVideoPlayer extends StatelessWidget {
  const NetworkWebVideoPlayer({required this.videoUrl, super.key});

  final String videoUrl;

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
