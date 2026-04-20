import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/common/widgets/video_card_widget.dart';
import 'package:video/core/models/content_search_result.dart';
import 'package:video/core/models/series_history_item_model.dart';
import 'package:video/core/models/series_model.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/models/watch_history_item_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/content_search_provider.dart';
import 'package:video/core/providers/series_catalog_provider.dart';
import 'package:video/core/providers/video_catalog_provider.dart';
import 'package:video/core/providers/watch_history_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchActive = false;
  String _searchInput = '';
  String _searchQuery = '';
  String _selectedGenre = 'All';
  final ScrollController _scrollController = ScrollController();
  bool _navSolid = false;

  static const List<String> _genres = [
    'All',
    'Action',
    'Animation',
    'Comedy',
    'Drama',
    'Horror',
    'Romance',
    'Series',
    'Thriller',
    'Sci-Fi',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(videoCatalogProvider.notifier).loadCatalog();
      ref.read(seriesCatalogProvider.notifier).loadSeriesCatalog();
      ref.read(watchHistoryProvider.notifier).loadHistory();
    });
    _searchController.addListener(_handleSearchInputChanged);
    _scrollController.addListener(() {
      final solid = _scrollController.offset > 60;
      if (solid != _navSolid) setState(() => _navSolid = solid);
    });
  }

  void _handleSearchInputChanged() {
    final nextValue = _searchController.text;
    if (nextValue == _searchInput) {
      return;
    }

    setState(() {
      _searchInput = nextValue;
    });
  }

  void _clearSearch({bool closeSearch = false}) {
    _searchController.clear();
    setState(() {
      _searchInput = '';
      _searchQuery = '';
      if (closeSearch) {
        _searchActive = false;
      }
    });
  }

  void _submitSearch([String? rawQuery]) {
    final normalizedQuery = (rawQuery ?? _searchController.text).trim();
    setState(() {
      _searchQuery = normalizedQuery;
      _searchActive = false;
    });
  }

  void _openSearchResult(BuildContext context, ContentSearchResult result) {
    _clearSearch(closeSearch: true);

    switch (result.type) {
      case ContentSearchResultType.video:
        context.push('/video/${result.id}');
        break;
      case ContentSearchResultType.reel:
        context.push('/reels?reelId=${result.id}');
        break;
      case ContentSearchResultType.series:
        context.push('/series/${result.id}');
        break;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchInputChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(videoCatalogProvider);
    final seriesState = ref.watch(seriesCatalogProvider);
    final authState = ref.watch(authProvider);
    final historyState = ref.watch(watchHistoryProvider);
    final seriesHistoryAsync = ref.watch(seriesHistoryProvider);
    final videos = catalogState.videos;
    final series = seriesState.series;
    final historyItems = historyState.items;
    final seriesHistoryItems =
        seriesHistoryAsync.valueOrNull ?? const <SeriesHistoryItemModel>[];
    final continueWatchingLoading =
        historyState.isLoading || seriesHistoryAsync.isLoading;
    final continueWatchingItems = <_ContinueWatchingEntry>[
      ...historyItems.map(_ContinueWatchingEntry.video),
      ...seriesHistoryItems.map(_ContinueWatchingEntry.series),
    ]..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    final reelsAsync = ref.watch(reelsCatalogProvider);
    final reels = reelsAsync.valueOrNull ?? const <VideoModel>[];
    final trimmedSearchInput = _searchInput.trim();
    final liveSearchResultsAsync =
        _searchActive && trimmedSearchInput.isNotEmpty
        ? ref.watch(
            unifiedContentSearchProvider(
              ContentSearchRequest(
                query: trimmedSearchInput,
                selectedGenre: _selectedGenre,
              ),
            ),
          )
        : null;
    final hasActiveSearch = _searchQuery.trim().isNotEmpty;
    final searchResultsAsync = hasActiveSearch
        ? ref.watch(
            unifiedContentSearchProvider(
              ContentSearchRequest(
                query: _searchQuery.trim(),
                selectedGenre: _selectedGenre,
              ),
            ),
          )
        : null;
    final searchResults =
        searchResultsAsync?.valueOrNull ?? const <ContentSearchResult>[];

    // Auth-change reload is now handled inside WatchHistoryNotifier itself.

    // Filter by genre
    final filtered = _selectedGenre == 'All'
        ? videos
        : videos
              .where(
                (v) => v.genre.toLowerCase() == _selectedGenre.toLowerCase(),
              )
              .toList();
    final filteredSeries = _selectedGenre == 'Series'
        ? series
        : series
              .where(
                (item) =>
                    item.genre.toLowerCase() == _selectedGenre.toLowerCase(),
              )
              .toList();
    // Rows by category
    final featuredVideos = videos.where((v) => v.isFeatured).toList();
    final featuredSeries = series.where((item) => item.isFeatured).toList();
    final freeVideos = videos.where((v) => !v.requiresPremium).toList();
    final premiumVideos = videos.where((v) => v.requiresPremium).toList();
    final heroVideo = featuredVideos.isNotEmpty
        ? featuredVideos.first
        : videos.isNotEmpty
        ? videos.first
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      body: Stack(
        children: [
          // Main content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Hero Banner
              SliverToBoxAdapter(
                child: heroVideo != null
                    ? _HeroBanner(
                        video: heroVideo,
                        onPlay: () => context.push(
                          '/video/${heroVideo.id}?autoplay=true',
                        ),
                        onMoreInfo: () =>
                            context.push('/video/${heroVideo.id}'),
                      )
                    : catalogState.isLoading
                    ? _HeroSkeleton()
                    : const SizedBox(height: 200),
              ),

              // Genre filter chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _genres.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final g = _genres[i];
                        final selected = g == _selectedGenre;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedGenre = g),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFF05454)
                                  : const Color(0xFF162235),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFF05454)
                                    : const Color(0xFF243247),
                              ),
                            ),
                            child: Text(
                              g,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white60,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Search results
              if (hasActiveSearch) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _selectedGenre == 'All'
                          ? 'Results for "$_searchQuery" (${searchResults.length})'
                          : 'Results for "$_searchQuery" in $_selectedGenre (${searchResults.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (searchResultsAsync?.isLoading == true)
                  SliverToBoxAdapter(child: _LoadingSkeleton())
                else if (searchResultsAsync?.hasError == true)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          'Unable to load search results',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                  )
                else if (searchResults.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          _selectedGenre == 'All'
                              ? 'No matching content found for "$_searchQuery"'
                              : 'No matching $_selectedGenre content found for "$_searchQuery"',
                          style: const TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final item = searchResults[index];
                        return _SearchResultTile(
                          result: item,
                          onTap: () => _openSearchResult(context, item),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                    ),
                  ),

                // Filtered grid or rows
              ] else if (_selectedGenre == 'Series') ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Series (${filteredSeries.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: filteredSeries.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text(
                                seriesState.isLoading
                                    ? 'Loading series...'
                                    : 'No series available yet',
                                style: const TextStyle(color: Colors.white38),
                              ),
                            ),
                          ),
                        )
                      : SliverGrid(
                          delegate: SliverChildBuilderDelegate((context, i) {
                            final item = filteredSeries[i];
                            return _SeriesCard(
                              series: item,
                              onTap: () => context.push('/series/${item.id}'),
                            );
                          }, childCount: filteredSeries.length),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.68,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                        ),
                ),
              ] else if (_selectedGenre != 'All') ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '$_selectedGenre (${filtered.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: filtered.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text(
                                'No $_selectedGenre videos yet',
                                style: const TextStyle(color: Colors.white38),
                              ),
                            ),
                          ),
                        )
                      : SliverGrid(
                          delegate: SliverChildBuilderDelegate((context, i) {
                            final v = filtered[i];
                            return VideoCardWidget(
                              title: v.title,
                              thumbnailUrl: v.thumbnailUrl,
                              rating: v.rating,
                              isPremium: v.requiresPremium,
                              isFree: !v.requiresPremium,
                              genre: v.genre,
                              durationSeconds: v.duration,
                              onTap: () => context.push('/video/${v.id}'),
                            );
                          }, childCount: filtered.length),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.65,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                        ),
                ),
              ] else ...[
                if (reels.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ReelsPromoRow(
                      reels: reels,
                      onOpenFeed: () => context.push('/reels'),
                    ),
                  ),

                if (!continueWatchingLoading &&
                    continueWatchingItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ContinueWatchingRow(
                      items: continueWatchingItems,
                      onOpenHistory: () => context.push('/history'),
                      onTap: (item) => context.push(item.routeLocation),
                    ),
                  ),

                if (featuredSeries.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _SeriesHorizontalRow(
                      title: 'Featured Series',
                      badge: 'BINGE NOW',
                      badgeColor: const Color(0xFF1F9DCC),
                      series: featuredSeries,
                      onTap: (item) => context.push('/series/${item.id}'),
                    ),
                  ),

                if (series.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _SeriesHorizontalRow(
                      title: 'TV Series',
                      series: series,
                      onTap: (item) => context.push('/series/${item.id}'),
                    ),
                  ),

                // "All Videos" row
                if (videos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalRow(
                      title: 'All Videos',
                      videos: videos,
                      onTap: (v) => context.push('/video/${v.id}'),
                    ),
                  ),

                // Free videos row
                if (freeVideos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalRow(
                      title: 'Free to Watch',
                      badge: 'FREE',
                      badgeColor: const Color(0xFF21A45D),
                      videos: freeVideos,
                      onTap: (v) => context.push('/video/${v.id}'),
                    ),
                  ),

                // Premium videos row
                if (premiumVideos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalRow(
                      title: 'Premium',
                      badge: 'PREMIUM',
                      badgeColor: const Color(0xFFF05454),
                      videos: premiumVideos,
                      onTap: (v) => context.push('/video/${v.id}'),
                    ),
                  ),

                // Empty state
                if (videos.isEmpty &&
                    series.isEmpty &&
                    !catalogState.isLoading &&
                    !seriesState.isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.movie_outlined,
                              color: Colors.white24,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No content yet',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Loading skeleton
                if ((catalogState.isLoading && videos.isEmpty) ||
                    (seriesState.isLoading && series.isEmpty))
                  SliverToBoxAdapter(child: _LoadingSkeleton()),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),

          // Fixed top nav bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _NavBar(
              solid: _navSolid,
              username: authState.user?.username,
              isAuthenticated: authState.isAuthenticated,
              isPremium: authState.user?.isPremium ?? false,
              isAdmin: authState.user?.isAdmin ?? false,
              searchActive: _searchActive,
              searchController: _searchController,
              liveSearchResults: liveSearchResultsAsync,
              onSearchToggle: () {
                if (_searchActive) {
                  _clearSearch(closeSearch: true);
                  return;
                }

                setState(() {
                  _searchActive = true;
                });
              },
              onSearchSubmit: _submitSearch,
              onSearchClear: () => _clearSearch(closeSearch: true),
              onSearchResultTap: (result) => _openSearchResult(context, result),
              onLogout: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              onOpenHistory: () => context.push('/history'),
              onOpenReels: () => context.push('/reels'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// NAV BAR
// ─────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final bool solid;
  final String? username;
  final bool isAuthenticated;
  final bool isPremium;
  final bool isAdmin;
  final bool searchActive;
  final TextEditingController searchController;
  final AsyncValue<List<ContentSearchResult>>? liveSearchResults;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearchSubmit;
  final VoidCallback onSearchClear;
  final ValueChanged<ContentSearchResult> onSearchResultTap;
  final VoidCallback onLogout;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenReels;

  const _NavBar({
    required this.solid,
    required this.username,
    required this.isAuthenticated,
    required this.isPremium,
    required this.isAdmin,
    required this.searchActive,
    required this.searchController,
    required this.liveSearchResults,
    required this.onSearchToggle,
    required this.onSearchSubmit,
    required this.onSearchClear,
    required this.onSearchResultTap,
    required this.onLogout,
    required this.onOpenHistory,
    required this.onOpenReels,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: solid
          ? const Color(0xFF070B12).withValues(alpha: 0.97)
          : Colors.transparent,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF05454),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'StreamOTT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Search field
            if (searchActive)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search movies, shows...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF162235),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: onSearchClear,
                          ),
                        ),
                        onSubmitted: onSearchSubmit,
                      ),
                      if (searchController.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _SearchSuggestionPanel(
                            results: liveSearchResults,
                            onResultTap: onSearchResultTap,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // Search icon
            if (!searchActive)
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white70),
                onPressed: onSearchToggle,
              ),

            const SizedBox(width: 4),

            // Profile / guest menu
            PopupMenuButton<String>(
              offset: const Offset(0, 44),
              color: const Color(0xFF101826),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1F9DCC),
                    child: Text(
                      (username ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    username ?? 'Guest',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 18,
                  ),
                ],
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Row(
                    children: [
                      Icon(
                        isPremium
                            ? Icons.workspace_premium_outlined
                            : Icons.lock_open_rounded,
                        size: 18,
                        color: isPremium
                            ? const Color(0xFFFFB44C)
                            : Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isAuthenticated
                            ? (isPremium
                                  ? 'Current Status: Premium'
                                  : 'Current Status: Free')
                            : 'Current Status: Guest',
                        style: TextStyle(
                          color: isPremium
                              ? const Color(0xFFFFB44C)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'reels',
                  child: Row(
                    children: [
                      Icon(
                        Icons.video_collection_outlined,
                        size: 18,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 10),
                      Text('Reels', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 10),
                      Text('History', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'plans',
                  child: Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        size: 18,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Subscription Plans',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                if (!isAuthenticated) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'login',
                    child: Row(
                      children: [
                        Icon(Icons.login, size: 18, color: Colors.white70),
                        SizedBox(width: 10),
                        Text('Sign In', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'register',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          size: 18,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Create Account',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isAdmin) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 18,
                          color: Color(0xFFFFB44C),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Admin Panel',
                          style: TextStyle(color: Color(0xFFFFB44C)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isAuthenticated) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: Color(0xFFF05454),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Sign Out',
                          style: TextStyle(color: Color(0xFFF05454)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              onSelected: (v) {
                if (v == 'logout') onLogout();
                if (v == 'history') onOpenHistory();
                if (v == 'reels') onOpenReels();
                if (v == 'plans') context.go('/plans');
                if (v == 'admin') context.go('/admin');
                if (v == 'login') context.go('/login');
                if (v == 'register') context.go('/register');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSuggestionPanel extends StatelessWidget {
  const _SearchSuggestionPanel({
    required this.results,
    required this.onResultTap,
  });

  final AsyncValue<List<ContentSearchResult>>? results;
  final ValueChanged<ContentSearchResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF243247)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: results == null
              ? const SizedBox.shrink()
              : results!.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              color: Colors.white38,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'No matching content found',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      );
                    }

                    final visibleItems = items.take(6).toList(growable: false);
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFF1B2638)),
                      itemBuilder: (context, index) {
                        final result = visibleItems[index];
                        return InkWell(
                          onTap: () => onResultTap(result),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 72,
                                    height: 44,
                                    child: result.imageUrl.isEmpty
                                        ? Container(
                                            color: const Color(0xFF162235),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              result.type.icon,
                                              color: Colors.white38,
                                              size: 18,
                                            ),
                                          )
                                        : Image.network(
                                            result.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  color: const Color(
                                                    0xFF162235,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    result.type.icon,
                                                    color: Colors.white38,
                                                    size: 18,
                                                  ),
                                                ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        result.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        result.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: result.type.badgeColor.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    result.type.label,
                                    style: TextStyle(
                                      color: result.type.badgeColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFF05454),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Searching all content...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  error: (_, _) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.white38,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Unable to load search results',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final ContentSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101826),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF243247)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 132,
                  height: 74,
                  child: result.imageUrl.isNotEmpty
                      ? Image.network(
                          result.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF162235),
                            alignment: Alignment.center,
                            child: Icon(
                              result.type.icon,
                              color: Colors.white30,
                              size: 28,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF162235),
                          alignment: Alignment.center,
                          child: Icon(
                            result.type.icon,
                            color: Colors.white30,
                            size: 28,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: result.type.badgeColor.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            result.type.label,
                            style: TextStyle(
                              color: result.type.badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (result.requiresPremium)
                          const _SearchTag(
                            label: 'Premium',
                            color: Color(0xFFF05454),
                          )
                        else
                          const _SearchTag(
                            label: 'Free',
                            color: Color(0xFF21A45D),
                          ),
                        if (result.isFeatured)
                          const _SearchTag(
                            label: 'Featured',
                            color: Color(0xFFFFB44C),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchTag extends StatelessWidget {
  const _SearchTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReelsPromoRow extends StatelessWidget {
  const _ReelsPromoRow({required this.reels, required this.onOpenFeed});

  final List<VideoModel> reels;
  final VoidCallback onOpenFeed;

  @override
  Widget build(BuildContext context) {
    final previewReels = reels.take(5).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Quick vertical clips with the same library access rules.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onOpenFeed,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB44C),
                  foregroundColor: const Color(0xFF0D1520),
                ),
                icon: const Icon(Icons.video_collection_outlined),
                label: const Text('Open Reels'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: previewReels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final reel = previewReels[index];
                return GestureDetector(
                  onTap: () => context.push('/reels?reelId=${reel.id}'),
                  child: Container(
                    width: 128,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF101826),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF243247)),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (reel.thumbnailUrl.isNotEmpty)
                          Image.network(
                            reel.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: const Color(0xFF162235)),
                          )
                        else
                          Container(color: const Color(0xFF162235)),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x12000000),
                                Color(0x22000000),
                                Color(0xDD000000),
                              ],
                              stops: [0, 0.4, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: reel.requiresPremium
                                  ? const Color(0xFFF05454)
                                  : const Color(0xFF21A45D),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              reel.requiresPremium ? 'Premium' : 'Free',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const Center(
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Color(0x99000000),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                reel.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFB44C),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    reel.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// HERO BANNER
// ─────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onPlay;
  final VoidCallback onMoreInfo;

  const _HeroBanner({
    required this.video,
    required this.onPlay,
    required this.onMoreInfo,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = w > 900 ? 520.0 : 300.0;
    final heroBadgeLabel = video.isFeatured ? 'FEATURED' : 'NOW STREAMING';
    final heroBadgeColor = video.isFeatured
        ? const Color(0xFFF05454)
        : const Color(0xFF1F9DCC);

    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop image
          Image.network(
            video.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF101826),
              child: const Center(
                child: Icon(
                  Icons.movie_outlined,
                  color: Colors.white12,
                  size: 80,
                ),
              ),
            ),
          ),

          // Gradient overlays
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 1.0],
                colors: [
                  Color(0x66070B12),
                  Colors.transparent,
                  Color(0xFF070B12),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xCC070B12), Colors.transparent],
              ),
            ),
          ),

          // Content
          Positioned(
            bottom: 40,
            left: 28,
            right: w * 0.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hero badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: heroBadgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    heroBadgeLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  video.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: w > 900 ? 42 : 26,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),

                // Meta
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB44C),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      video.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Color(0xFFFFB44C),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (video.genre.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.genre,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (!video.requiresPremium) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21A45D),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  video.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text(
                        'Play Now',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05454),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onMoreInfo,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text(
                        'More Info',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingRow extends StatelessWidget {
  const _ContinueWatchingRow({
    required this.items,
    required this.onTap,
    required this.onOpenHistory,
  });

  final List<_ContinueWatchingEntry> items;
  final ValueChanged<_ContinueWatchingEntry> onTap;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue Watching',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your last 10 videos, reels, and episodes.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onOpenHistory,
                  child: const Text(
                    'See All',
                    style: TextStyle(color: Color(0xFF1F9DCC)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: 210,
                  child: _ContinueWatchingCard(
                    item: item,
                    onTap: () => onTap(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends StatefulWidget {
  const _ContinueWatchingCard({required this.item, required this.onTap});

  final _ContinueWatchingEntry item;
  final VoidCallback onTap;

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  bool _hovered = false;

  String _formatTime(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }

    return '${duration.inMinutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_hovered ? 1.02 : 1.0),
          decoration: BoxDecoration(
            color: const Color(0xFF101826),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF1F9DCC)
                  : const Color(0xFF243247),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        entry.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF162235),
                          alignment: Alignment.center,
                          child: Icon(
                            entry.isSeries
                                ? Icons.live_tv_rounded
                                : Icons.movie_outlined,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x22000000), Color(0xCC000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC070B12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            entry.hasResumePosition
                                ? 'Resume ${_formatTime(entry.watchedSeconds)}'
                                : 'Start over',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Center(
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Color(0x99000000),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.subtitle != null) ...[
                        Text(
                          entry.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: entry.progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF243247),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFF05454),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatTime(entry.watchedSeconds)} of ${_formatTime(entry.durationSeconds)} watched',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueWatchingEntry {
  const _ContinueWatchingEntry({
    required this.title,
    required this.thumbnailUrl,
    required this.watchedAt,
    required this.watchedSeconds,
    required this.durationSeconds,
    required this.progress,
    required this.hasResumePosition,
    required this.routeLocation,
    required this.isSeries,
    this.subtitle,
  });

  factory _ContinueWatchingEntry.video(WatchHistoryItemModel item) {
    return _ContinueWatchingEntry(
      title: item.video.title,
      thumbnailUrl: item.video.thumbnailUrl,
      watchedAt: item.watchedAt,
      watchedSeconds: item.durationWatchedSeconds,
      durationSeconds: item.video.duration,
      progress: item.progress,
      hasResumePosition: item.hasResumePosition,
      routeLocation: '/video/${item.videoId}',
      isSeries: false,
      subtitle: item.video.isReel ? 'Reel' : item.video.genre,
    );
  }

  factory _ContinueWatchingEntry.series(SeriesHistoryItemModel item) {
    final thumbnailUrl = item.episode.thumbnailUrl.isNotEmpty
        ? item.episode.thumbnailUrl
        : item.series.posterUrl;
    return _ContinueWatchingEntry(
      title: item.episode.title,
      thumbnailUrl: thumbnailUrl,
      watchedAt: item.lastWatchedAt,
      watchedSeconds: item.positionSeconds,
      durationSeconds: item.episode.duration,
      progress: item.progress,
      hasResumePosition: item.hasResumePosition,
      routeLocation: '/series/${item.seriesId}/episode/${item.episodeId}',
      isSeries: true,
      subtitle: '${item.series.title} • Episode ${item.episode.episodeNumber}',
    );
  }

  final String title;
  final String thumbnailUrl;
  final DateTime watchedAt;
  final int watchedSeconds;
  final int durationSeconds;
  final double progress;
  final bool hasResumePosition;
  final String routeLocation;
  final bool isSeries;
  final String? subtitle;
}

// ─────────────────────────────────────────
// HORIZONTAL ROW
// ─────────────────────────────────────────
class _HorizontalRow extends StatelessWidget {
  final String title;
  final String? badge;
  final Color? badgeColor;
  final List<VideoModel> videos;
  final ValueChanged<VideoModel> onTap;

  const _HorizontalRow({
    required this.title,
    this.badge,
    this.badgeColor,
    required this.videos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'See All',
                    style: TextStyle(color: Color(0xFF1F9DCC), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal scroll
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final v = videos[i];
                return SizedBox(
                  width: 145,
                  child: VideoCardWidget(
                    title: v.title,
                    thumbnailUrl: v.thumbnailUrl,
                    rating: v.rating,
                    isPremium: v.requiresPremium,
                    isFree: !v.requiresPremium,
                    genre: v.genre,
                    durationSeconds: v.duration,
                    onTap: () => onTap(v),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesHorizontalRow extends StatelessWidget {
  const _SeriesHorizontalRow({
    required this.title,
    required this.series,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  final String title;
  final List<SeriesModel> series;
  final ValueChanged<SeriesModel> onTap;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Browse Series',
                    style: TextStyle(color: Color(0xFF1F9DCC), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 245,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: series.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = series[index];
                return SizedBox(
                  width: 176,
                  child: _SeriesCard(series: item, onTap: () => onTap(item)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series, required this.onTap});

  final SeriesModel series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = series.posterUrl.isNotEmpty
        ? series.posterUrl
        : series.backdropUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101826),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF243247)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF162235),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.live_tv_rounded,
                          color: Colors.white30,
                          size: 34,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF162235),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.live_tv_rounded,
                        color: Colors.white30,
                        size: 34,
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xDD070B12)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: series.requiresPremium
                            ? const Color(0xFFF05454)
                            : const Color(0xFF21A45D),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        series.requiresPremium ? 'Premium' : 'Free',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (series.isFeatured)
                    const Positioned(
                      top: 10,
                      right: 10,
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFFB44C),
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${series.seasonCount} seasons • ${series.episodeCount} episodes',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    series.genre,
                    style: const TextStyle(
                      color: Color(0xFF1F9DCC),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// SKELETON LOADERS
// ─────────────────────────────────────────
class _HeroSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.width > 900 ? 520.0 : 300.0;
    return _Shimmer(
      child: Container(height: h, color: const Color(0xFF162235)),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Shimmer(
            child: Container(
              height: 20,
              width: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF162235),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => _Shimmer(
                child: Container(
                  width: 145,
                  decoration: BoxDecoration(
                    color: const Color(0xFF162235),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _anim, child: widget.child);
}
