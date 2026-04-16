import 'package:flutter/material.dart';

class BunnyWebPlayer extends StatelessWidget {
  const BunnyWebPlayer({
    required this.videoUrl,
    this.capturePointerEvents = true,
    super.key,
  });

  final String videoUrl;
  final bool capturePointerEvents;

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
