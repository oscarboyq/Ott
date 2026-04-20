import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/core/models/content_search_result.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/providers/service_providers.dart';

class ContentSearchRequest {
  const ContentSearchRequest({required this.query, this.selectedGenre = 'All'});

  final String query;
  final String selectedGenre;

  @override
  bool operator ==(Object other) {
    return other is ContentSearchRequest &&
        other.query == query &&
        other.selectedGenre == selectedGenre;
  }

  @override
  int get hashCode => Object.hash(query, selectedGenre);
}

String _normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _matchesGenre({
  required String selectedGenre,
  required String itemGenre,
  required ContentSearchResultType type,
}) {
  if (selectedGenre == 'All') {
    return true;
  }

  if (selectedGenre == 'Series') {
    return type == ContentSearchResultType.series;
  }

  return _normalizeSearchText(itemGenre) == _normalizeSearchText(selectedGenre);
}

bool _matchesQuery({
  required String query,
  required String title,
  required String genre,
}) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.isEmpty) {
    return false;
  }

  final normalizedTitle = _normalizeSearchText(title);
  final normalizedGenre = _normalizeSearchText(genre);

  if (normalizedTitle.contains(normalizedQuery) ||
      normalizedGenre.contains(normalizedQuery)) {
    return true;
  }

  final queryTokens = normalizedQuery.split(' ');
  return queryTokens.every(
    (token) =>
        normalizedTitle.contains(token) || normalizedGenre.contains(token),
  );
}

final unifiedContentSearchProvider =
    FutureProvider.family<List<ContentSearchResult>, ContentSearchRequest>((
      ref,
      request,
    ) async {
      final normalizedQuery = _normalizeSearchText(request.query);
      if (normalizedQuery.isEmpty) {
        return const <ContentSearchResult>[];
      }

      final apiService = ref.watch(apiServiceProvider);
      final results = await Future.wait<dynamic>([
        apiService.getVideoCatalog(page: 1, limit: 200, includeReels: true),
        apiService.getSeriesCatalog(page: 1, limit: 200),
      ]);

      final videos = (results[0] as Iterable)
          .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);

      final series = (results[1] as Iterable)
          .map((item) => SeriesModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);

      final combined = <ContentSearchResult>[
        ...videos
            .where((video) {
              final type = video.isReel
                  ? ContentSearchResultType.reel
                  : ContentSearchResultType.video;
              return _matchesGenre(
                    selectedGenre: request.selectedGenre,
                    itemGenre: video.genre,
                    type: type,
                  ) &&
                  _matchesQuery(
                    query: normalizedQuery,
                    title: video.title,
                    genre: video.genre,
                  );
            })
            .map((video) => ContentSearchResult.video(video: video)),
        ...series
            .where((item) {
              return _matchesGenre(
                    selectedGenre: request.selectedGenre,
                    itemGenre: item.genre,
                    type: ContentSearchResultType.series,
                  ) &&
                  _matchesQuery(
                    query: normalizedQuery,
                    title: item.title,
                    genre: item.genre,
                  );
            })
            .map((item) => ContentSearchResult.series(series: item)),
      ];

      combined.sort((a, b) {
        final aFeaturedScore = a.isFeatured ? 1 : 0;
        final bFeaturedScore = b.isFeatured ? 1 : 0;
        if (aFeaturedScore != bFeaturedScore) {
          return bFeaturedScore.compareTo(aFeaturedScore);
        }

        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      return combined;
    });
