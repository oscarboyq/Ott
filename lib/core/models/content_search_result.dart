import 'package:flutter/material.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/video_model.dart';

enum ContentSearchResultType { video, reel, series }

extension ContentSearchResultTypePresentation on ContentSearchResultType {
  String get label {
    switch (this) {
      case ContentSearchResultType.video:
        return 'VIDEO';
      case ContentSearchResultType.reel:
        return 'REEL';
      case ContentSearchResultType.series:
        return 'SERIES';
    }
  }

  Color get badgeColor {
    switch (this) {
      case ContentSearchResultType.video:
        return const Color(0xFF1F9DCC);
      case ContentSearchResultType.reel:
        return const Color(0xFFFFB44C);
      case ContentSearchResultType.series:
        return const Color(0xFFF05454);
    }
  }

  IconData get icon {
    switch (this) {
      case ContentSearchResultType.video:
        return Icons.movie_creation_outlined;
      case ContentSearchResultType.reel:
        return Icons.video_collection_outlined;
      case ContentSearchResultType.series:
        return Icons.live_tv_rounded;
    }
  }
}

class ContentSearchResult {
  const ContentSearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.imageUrl,
    required this.subtitle,
    required this.isFeatured,
    required this.requiresPremium,
  });

  factory ContentSearchResult.video({required VideoModel video}) {
    return ContentSearchResult(
      id: video.id,
      type: video.isReel
          ? ContentSearchResultType.reel
          : ContentSearchResultType.video,
      title: video.title,
      imageUrl: video.thumbnailUrl,
      subtitle: video.isReel
          ? '${video.genre} • Reel'
          : '${video.genre} • ${video.duration ~/ 60} min',
      isFeatured: video.isFeatured,
      requiresPremium: video.requiresPremium,
    );
  }

  factory ContentSearchResult.series({required SeriesModel series}) {
    return ContentSearchResult(
      id: series.id,
      type: ContentSearchResultType.series,
      title: series.title,
      imageUrl: series.posterUrl.isNotEmpty
          ? series.posterUrl
          : series.backdropUrl,
      subtitle:
          '${series.genre} • ${series.seasonCount} seasons • ${series.episodeCount} episodes',
      isFeatured: series.isFeatured,
      requiresPremium: series.requiresPremium,
    );
  }

  final String id;
  final ContentSearchResultType type;
  final String title;
  final String imageUrl;
  final String subtitle;
  final bool isFeatured;
  final bool requiresPremium;
}
