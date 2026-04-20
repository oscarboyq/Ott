import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class NetworkWebVideoPlayer extends StatefulWidget {
  const NetworkWebVideoPlayer({required this.videoUrl, super.key});

  final String videoUrl;

  @override
  State<NetworkWebVideoPlayer> createState() => _NetworkWebVideoPlayerState();
}

class _NetworkWebVideoPlayerState extends State<NetworkWebVideoPlayer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'network-video-${widget.videoUrl.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final video = html.VideoElement()
        ..src = widget.videoUrl
        ..controls = true
        ..autoplay = false
        ..preload = 'metadata'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0'
        ..style.backgroundColor = '#101826';

      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
