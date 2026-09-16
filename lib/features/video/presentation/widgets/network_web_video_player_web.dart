import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class NetworkWebVideoPlayer extends StatefulWidget {
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
  State<NetworkWebVideoPlayer> createState() => _NetworkWebVideoPlayerState();
}

class _NetworkWebVideoPlayerState extends State<NetworkWebVideoPlayer> {
  late final String _viewType;
  html.VideoElement? _video;

  @override
  void initState() {
    super.initState();
    _viewType =
        'network-video-${widget.videoUrl.hashCode}-${widget.muted}-${widget.autoplay}-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final isAggressive =
          (widget.bufferProfile?.contains('Aggressive') ?? false) ||
          widget.preload == true;
      final isDataSaver =
          (widget.bufferProfile?.contains('Data Saver') ?? false) ||
          widget.preload == false;
      final preloadMode =
          isAggressive ? 'auto' : (isDataSaver ? 'none' : 'metadata');

      final video = html.VideoElement()
        ..src = widget.videoUrl
        ..controls = widget.showControls
        ..autoplay = widget.autoplay
        ..muted = widget.muted
        ..loop = widget.loop
        ..preload = preloadMode
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0'
        ..style.backgroundColor = '#101826'
        ..style.objectFit = 'cover';

      if (widget.muted) {
        video.muted = true;
        video.defaultMuted = true;
        video.volume = 0;
        video.setAttribute('muted', '');
      }
      video.setAttribute('playsinline', '');

      if (widget.initialPositionSeconds != null && widget.initialPositionSeconds! > 0) {
        video.onLoadedMetadata.first.then((_) {
          video.currentTime = widget.initialPositionSeconds!.toDouble();
        });
      }
      video.onTimeUpdate.listen((_) {
        widget.onPositionChanged?.call(video.currentTime.round());
      });

      _video = video;
      return video;
    });
  }

  @override
  void dispose() {
    try {
      if (_video != null) {
        _video!.pause();
        _video!.src = '';
        _video!.load();
        _video!.remove();
        _video = null;
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
