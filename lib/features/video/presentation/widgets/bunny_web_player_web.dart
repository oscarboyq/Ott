import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class BunnyWebPlayer extends StatefulWidget {
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
  State<BunnyWebPlayer> createState() => _BunnyWebPlayerState();
}

class _BunnyWebPlayerState extends State<BunnyWebPlayer> {
  late final String _viewType;
  late String _resolvedUrl;
  late final bool _isDirectMediaUrl;
  html.IFrameElement? _iframe;
  html.VideoElement? _video;
  StreamSubscription<html.MessageEvent>? _messageSub;

  void _sendSeekCommand(html.IFrameElement? iframe, int seconds) {
    if (iframe == null || seconds <= 0) return;
    try {
      final win = iframe.contentWindow;
      if (win != null) {
        win.postMessage('{"context":"player.js","version":"0.0.11","method":"setCurrentTime","value":$seconds}', '*');
        win.postMessage('{"context":"player.js","method":"setCurrentTime","value":$seconds}', '*');
        win.postMessage('{"method":"setCurrentTime","value":$seconds}', '*');
        win.postMessage('{"action":"seek","value":$seconds}', '*');
        win.postMessage('{"event":"command","func":"seekTo","args":[$seconds, true]}', '*');
      }
    } catch (_) {}
  }

  void _sendMuteCommand(html.IFrameElement? iframe) {
    if (iframe == null) return;
    try {
      final win = iframe.contentWindow;
      if (win != null) {
        win.postMessage('{"context":"player.js","version":"0.0.11","method":"mute"}', '*');
        win.postMessage('{"context":"player.js","method":"setVolume","value":0}', '*');
        win.postMessage('{"method":"mute"}', '*');
        win.postMessage('{"event":"command","func":"mute"}', '*');
        win.postMessage('{"action":"mute"}', '*');
        win.postMessage('{"type":"player:mute"}', '*');
        win.postMessage('{"method":"setVolume","value":0}', '*');
      }
    } catch (_) {}
  }

  void _sendQualityCommand(html.IFrameElement? iframe) {
    if (iframe == null) return;
    final qualityParam = _parseQualityParam(widget.streamQuality);
    if (qualityParam != null) {
      final numeric = int.tryParse(qualityParam.replaceAll('p', ''));
      try {
        final win = iframe.contentWindow;
        if (win != null) {
          // Standard Player.js specification
          win.postMessage(
            '{"context":"player.js","version":"0.0.11","event":"command","method":"setQuality","value":"$qualityParam"}',
            '*',
          );
          win.postMessage(
            '{"context":"player.js","method":"setQuality","value":"$qualityParam"}',
            '*',
          );
          win.postMessage(
            '{"context":"player.js","method":"setCurrentQuality","value":"$qualityParam"}',
            '*',
          );
          if (numeric != null) {
            win.postMessage(
              '{"context":"player.js","version":"0.0.11","event":"command","method":"setQuality","value":$numeric}',
              '*',
            );
            win.postMessage(
              '{"context":"player.js","method":"setQuality","value":$numeric}',
              '*',
            );
            win.postMessage(
              '{"context":"player.js","method":"setCurrentQuality","value":$numeric}',
              '*',
            );
          }
          // Generic cross-player fallbacks
          win.postMessage('{"method":"setQuality","value":"$qualityParam"}', '*');
          win.postMessage(
            '{"event":"command","func":"setQuality","args":["$qualityParam"]}',
            '*',
          );
          win.postMessage('{"type":"setQuality","quality":"$qualityParam"}', '*');
          win.postMessage('{"action":"setQuality","quality":"$qualityParam"}', '*');
          win.postMessage('{"api":"setQuality","value":"$qualityParam"}', '*');
        }
      } catch (_) {}
    }
  }

  void _sendEventListenerCommand(html.IFrameElement? iframe) {
    if (iframe == null) return;
    try {
      final win = iframe.contentWindow;
      if (win != null) {
        win.postMessage('{"context":"player.js","version":"0.0.11","method":"addEventListener","value":"timeupdate"}', '*');
        win.postMessage('{"context":"player.js","method":"addEventListener","value":"timeupdate"}', '*');
        win.postMessage('{"method":"addEventListener","value":"timeupdate"}', '*');
        win.postMessage('{"context":"player.js","version":"0.0.11","method":"addEventListener","value":"play"}', '*');
        win.postMessage('{"context":"player.js","version":"0.0.11","method":"addEventListener","value":"pause"}', '*');
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _resolvedUrl = _resolveIframeUrl(
      widget.videoUrl,
      explicitLibraryId: widget.libraryId,
    );
    _isDirectMediaUrl = _resolvedUrl.contains('.m3u8') || _resolvedUrl.contains('.mp4');
    _viewType =
        'bunny-player-${widget.videoUrl.hashCode}-${widget.muted}-${widget.autoplay}-${DateTime.now().microsecondsSinceEpoch}';

    _messageSub = html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        Map? mapData;
        if (data is Map) {
          mapData = data;
        } else if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map) {
              mapData = decoded;
            }
          } catch (_) {}
        }

        final dataStr = data?.toString() ?? '';
        final isReady = dataStr.contains('ready') ||
            (mapData != null && (mapData['event'] == 'ready' || mapData['method'] == 'ready'));
        if (isReady) {
          if (widget.muted) {
            _sendMuteCommand(_iframe);
          }
          _sendQualityCommand(_iframe);
          _sendEventListenerCommand(_iframe);
          if (widget.initialPositionSeconds != null && widget.initialPositionSeconds! > 0) {
            _sendSeekCommand(_iframe, widget.initialPositionSeconds!);
          }
        }

        final isTimeUpdate = dataStr.contains('timeupdate') ||
            dataStr.contains('time_update') ||
            (mapData != null &&
                (mapData['event'] == 'timeupdate' ||
                    mapData['event'] == 'time_update' ||
                    mapData['method'] == 'timeupdate'));

        if (isTimeUpdate && mapData != null) {
          final val = mapData['value'];
          int? secs;
          if (val is Map && val['seconds'] != null) {
            secs = (val['seconds'] as num).round();
          } else if (val is num) {
            secs = val.round();
          } else if (mapData['seconds'] != null) {
            secs = (mapData['seconds'] as num).round();
          } else if (mapData['currentTime'] != null) {
            secs = (mapData['currentTime'] as num).round();
          }
          if (secs != null && secs >= 0) {
            widget.onPositionChanged?.call(secs);
          }
        }
      } catch (_) {}
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      if (_isDirectMediaUrl) {
        // Raw media streams (.mp4 / .m3u8) rendered via HTML5 VideoElement.
        // Provides native hardware playback and clean controls without cross-origin iframe menus.
        final isAggressive =
            (widget.bufferProfile?.contains('Aggressive') ?? false) ||
            widget.preload == true;
        final isDataSaver =
            (widget.bufferProfile?.contains('Data Saver') ?? false) ||
            widget.preload == false;
        final video = html.VideoElement()
          ..src = _resolvedUrl
          ..controls = !widget.muted
          ..autoplay = widget.autoplay
          ..muted = widget.muted
          ..defaultMuted = widget.muted
          ..loop = widget.muted
          ..preload = isAggressive
              ? 'auto'
              : (isDataSaver ? 'none' : 'metadata')
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = '0'
          ..style.backgroundColor = '#101826'
          ..style.objectFit = widget.muted ? 'cover' : 'contain'
          ..style.pointerEvents = widget.capturePointerEvents ? 'auto' : 'none';
        if (widget.muted) {
          video.volume = 0;
          video.setAttribute('muted', '');
        }
        video.setAttribute('playsinline', '');

        if (widget.initialPositionSeconds != null && widget.initialPositionSeconds! > 0) {
          final resumeSecs = widget.initialPositionSeconds!.toDouble();
          if (video.readyState >= 1) {
            video.currentTime = resumeSecs;
          } else {
            video.onLoadedMetadata.first.then((_) {
              video.currentTime = resumeSecs;
            });
          }
        }
        video.onTimeUpdate.listen((_) {
          widget.onPositionChanged?.call(video.currentTime.round());
        });

        _video = video;
        return video;
      }

      final iframe = html.IFrameElement()
        ..src = _resolvedUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = widget.capturePointerEvents ? 'auto' : 'none'
        ..allow = widget.muted
            ? 'accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture'
            : 'accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture; fullscreen'
        ..allowFullscreen = !widget.muted;

      iframe.onLoad.listen((_) {
        if (widget.muted) {
          _sendMuteCommand(iframe);
          Future.delayed(const Duration(milliseconds: 300), () => _sendMuteCommand(iframe));
          Future.delayed(const Duration(milliseconds: 800), () => _sendMuteCommand(iframe));
          Future.delayed(const Duration(milliseconds: 1500), () => _sendMuteCommand(iframe));
        }
        _sendQualityCommand(iframe);
        _sendEventListenerCommand(iframe);
        Future.delayed(const Duration(milliseconds: 300), () => _sendQualityCommand(iframe));
        Future.delayed(const Duration(milliseconds: 400), () => _sendEventListenerCommand(iframe));
        Future.delayed(const Duration(milliseconds: 800), () => _sendQualityCommand(iframe));
        Future.delayed(const Duration(milliseconds: 1000), () => _sendEventListenerCommand(iframe));
        Future.delayed(const Duration(milliseconds: 1600), () => _sendQualityCommand(iframe));
        Future.delayed(const Duration(milliseconds: 2000), () => _sendEventListenerCommand(iframe));
        Future.delayed(const Duration(milliseconds: 2500), () => _sendQualityCommand(iframe));

        if (widget.initialPositionSeconds != null && widget.initialPositionSeconds! > 0) {
          _sendSeekCommand(iframe, widget.initialPositionSeconds!);
          Future.delayed(const Duration(milliseconds: 500), () => _sendSeekCommand(iframe, widget.initialPositionSeconds!));
          Future.delayed(const Duration(milliseconds: 1200), () => _sendSeekCommand(iframe, widget.initialPositionSeconds!));
          Future.delayed(const Duration(milliseconds: 2500), () => _sendSeekCommand(iframe, widget.initialPositionSeconds!));
        }
      });

      _iframe = iframe;
      return iframe;
    });
  }

  @override
  void didUpdateWidget(BunnyWebPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldUpdateUrl = oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.libraryId != widget.libraryId ||
        oldWidget.streamQuality != widget.streamQuality ||
        oldWidget.bufferProfile != widget.bufferProfile;

    if (shouldUpdateUrl) {
      _resolvedUrl = _resolveIframeUrl(
        widget.videoUrl,
        explicitLibraryId: widget.libraryId,
      );
      if (_iframe != null && _iframe!.src != _resolvedUrl) {
        _iframe!.src = _resolvedUrl;
      }
      _sendQualityCommand(_iframe);
    }
  }

  @override
  void dispose() {
    try {
      _messageSub?.cancel();
      _messageSub = null;
      if (_iframe != null) {
        _iframe!.src = 'about:blank';
        _iframe!.remove();
        _iframe = null;
      }
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

  String _resolveIframeUrl(
    String videoUrl, {
    String? explicitLibraryId,
  }) {
    final uri = Uri.tryParse(videoUrl.trim());
    if (uri == null) {
      return videoUrl;
    }

    final pathSegments = uri.pathSegments;
    final host = uri.host.toLowerCase();
    final isMediaDelivery =
        host.contains('mediadelivery.net') || host == 'video.bunnycdn.com';

    String? detectedLibraryId =
        (explicitLibraryId != null && explicitLibraryId.trim().isNotEmpty)
            ? explicitLibraryId.trim()
            : null;
    String? detectedGuid;

    if (isMediaDelivery && pathSegments.isNotEmpty) {
      if ((pathSegments[0] == 'embed' || pathSegments[0] == 'play') &&
          pathSegments.length >= 3) {
        detectedLibraryId ??= pathSegments[1];
        detectedGuid = pathSegments[2];
      } else if (pathSegments.length == 2 &&
          RegExp(r'^\d+$').hasMatch(pathSegments[0])) {
        detectedLibraryId ??= pathSegments[0];
        detectedGuid = pathSegments[1];
      }
    }

    if (host.contains('b-cdn.net') || host.startsWith('vz-')) {
      final vzDigitsMatch = RegExp(r'^vz-(\d+)\.b-cdn\.net$').firstMatch(host);
      if (vzDigitsMatch != null) {
        detectedLibraryId ??= vzDigitsMatch.group(1);
      }
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      for (final seg in pathSegments) {
        if (uuidRegex.hasMatch(seg)) {
          detectedGuid = seg;
          break;
        }
      }
      if (detectedGuid == null &&
          pathSegments.isNotEmpty &&
          pathSegments.first != 'playlist.m3u8') {
        detectedGuid = pathSegments.first;
      }
    }

    if (videoUrl.contains('.mp4')) {
      return videoUrl;
    }

    String baseEmbedUrl;
    if (detectedLibraryId != null &&
        detectedLibraryId.isNotEmpty &&
        detectedGuid != null &&
        detectedGuid.isNotEmpty) {
      baseEmbedUrl =
          'https://iframe.mediadelivery.net/embed/$detectedLibraryId/$detectedGuid';
    } else if (isMediaDelivery &&
        pathSegments.isNotEmpty &&
        pathSegments.first == 'embed') {
      baseEmbedUrl = '${uri.scheme}://${uri.host}${uri.path}';
    } else {
      baseEmbedUrl = videoUrl;
    }

    final baseUri = Uri.tryParse(baseEmbedUrl) ?? uri;
    final queryParams = Map<String, String>.from(baseUri.queryParameters);
    if (uri.queryParameters.isNotEmpty && baseUri != uri) {
      queryParams.addAll(uri.queryParameters);
    }
    if (widget.autoplay) {
      queryParams['autoplay'] = 'true';
    }
    final isAggressive =
        (widget.bufferProfile?.contains('Aggressive') ?? false) ||
        widget.preload == true;
    final isDataSaver =
        (widget.bufferProfile?.contains('Data Saver') ?? false) ||
        widget.preload == false;

    if (widget.muted) {
      queryParams['muted'] = 'true';
      queryParams['mute'] = '1';
      queryParams['volume'] = '0';
      queryParams['rememberSettings'] = 'false';
      queryParams['rememberPosition'] = 'false';
      queryParams['controls'] = 'false';
      queryParams['loop'] = 'true';
      queryParams['preload'] = 'true';
    } else {
      if (isAggressive) {
        queryParams['preload'] = 'true';
      } else if (isDataSaver) {
        queryParams['preload'] = 'false';
      }
      if (widget.initialPositionSeconds != null && widget.initialPositionSeconds! > 0) {
        queryParams['t'] = '${widget.initialPositionSeconds}';
        queryParams['start'] = '${widget.initialPositionSeconds}';
      }
    }

    final qualityParam = _parseQualityParam(widget.streamQuality);
    if (qualityParam != null) {
      final numeric = qualityParam.replaceAll('p', '');
      queryParams['quality'] = qualityParam;
      queryParams['defaultQuality'] = qualityParam;
      queryParams['resolution'] = numeric;
      queryParams['startQuality'] = qualityParam;
      queryParams['initialQuality'] = qualityParam;
    }

    return baseUri
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null)
        .toString();
  }

  String? _parseQualityParam(String? quality) {
    if (quality == null || quality.trim().isEmpty || quality.toLowerCase().contains('auto')) {
      return null;
    }
    if (quality.contains('4K') || quality.contains('2160')) return '2160p';
    if (quality.contains('1080')) return '1080p';
    if (quality.contains('720')) return '720p';
    if (quality.contains('480')) return '480p';
    if (quality.contains('360')) return '360p';
    if (quality.contains('240')) return '240p';
    return null;
  }
}
