import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class BunnyWebPlayer extends StatefulWidget {
  const BunnyWebPlayer({
    required this.videoUrl,
    this.capturePointerEvents = true,
    super.key,
  });

  final String videoUrl;
  final bool capturePointerEvents;

  @override
  State<BunnyWebPlayer> createState() => _BunnyWebPlayerState();
}

class _BunnyWebPlayerState extends State<BunnyWebPlayer> {
  late final String _viewType;
  late final String _iframeUrl;

  @override
  void initState() {
    super.initState();
    _iframeUrl = _resolveIframeUrl(widget.videoUrl);
    _viewType =
        'bunny-player-${widget.videoUrl.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = _iframeUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = widget.capturePointerEvents ? 'auto' : 'none'
        ..allow =
            'accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture; fullscreen'
        ..allowFullscreen = true;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }

  String _resolveIframeUrl(String videoUrl) {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) {
      return videoUrl;
    }

    if (uri.host == 'iframe.mediadelivery.net') {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'embed') {
        return videoUrl;
      }
      return videoUrl;
    }

    final hostMatch = RegExp(r'^vz-(\d+)\.b-cdn\.net$').firstMatch(uri.host);
    final pathSegments = uri.pathSegments;
    if (hostMatch != null && pathSegments.length >= 2) {
      final libraryId = hostMatch.group(1)!;
      final guid = pathSegments.first;
      return 'https://iframe.mediadelivery.net/embed/$libraryId/$guid';
    }

    return videoUrl;
  }
}
