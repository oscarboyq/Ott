import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video/app/app.dart';
import 'package:video/core/models/user_model.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/series_catalog_provider.dart';
import 'package:video/core/providers/video_catalog_provider.dart';
import 'package:video/core/providers/watch_history_provider.dart';
import 'package:video/features/catalog/presentation/pages/home_page.dart';
import 'package:video/features/setup/presentation/pages/setup_status_error_page.dart';

class MockVideoCatalogNotifier extends StateNotifier<VideoCatalogState>
    implements VideoCatalogNotifier {
  MockVideoCatalogNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> loadCatalog({bool refresh = false, String? genre}) async {}
}

class MockSeriesCatalogNotifier extends StateNotifier<SeriesCatalogState>
    implements SeriesCatalogNotifier {
  MockSeriesCatalogNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> loadSeriesCatalog({String? genre}) async {}
}

class MockWatchHistoryNotifier extends StateNotifier<WatchHistoryState>
    implements WatchHistoryNotifier {
  MockWatchHistoryNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> loadHistory() async {}
}

class MockAuthStateNotifier extends StateNotifier<AuthState>
    implements AuthStateNotifier {
  MockAuthStateNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OttApp startup and routing', () {
    testWidgets('renders SetupStatusErrorPage when backend configuration is uninitialized', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: OttApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to check installation'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Setting up a new Supabase project?'), findsOneWidget);
    });

    testWidgets('SetupStatusErrorPage displays proper guidance and error explanation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SetupStatusErrorPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to check installation'), findsOneWidget);
      expect(
        find.textContaining('ReelHouse could not read its setup status'),
        findsOneWidget,
      );
    });
  });

  group('HomePage catalog display', () {
    testWidgets('renders brand title, genre chips, and navigation elements', (
      WidgetTester tester,
    ) async {
      final sampleVideo = VideoModel(
        id: 'test-vid-1',
        title: 'Spotlight Feature',
        description: 'An exclusive premiere film.',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        videoUrl: 'https://example.com/stream.mp4',
        genre: 'Action',
        rating: 4.8,
        ratingCount: 120,
        duration: 5400,
        viewCount: 1500,
        requiresPremium: false,
        isFeatured: true,
        releaseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => MockAuthStateNotifier(
                AuthState(
                  hasInitialized: true,
                  isAuthenticated: true,
                  user: UserModel(
                    id: 'user-1',
                    email: 'admin@streamott.com',
                    username: 'OttAdmin',
                    isAdmin: true,
                    isPremium: true,
                    createdAt: DateTime(2025, 1, 1),
                  ),
                ),
              ),
            ),
            videoCatalogProvider.overrideWith(
              (ref) => MockVideoCatalogNotifier(
                VideoCatalogState(
                  videos: [sampleVideo],
                  isLoading: false,
                ),
              ),
            ),
            seriesCatalogProvider.overrideWith(
              (ref) => MockSeriesCatalogNotifier(
                const SeriesCatalogState(
                  series: [],
                  isLoading: false,
                ),
              ),
            ),
            watchHistoryProvider.overrideWith(
              (ref) => MockWatchHistoryNotifier(
                const WatchHistoryState(
                  items: [],
                  isLoading: false,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Brand logo text in navbar
      expect(find.text('StreamOTT'), findsOneWidget);

      // Genre chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Animation'), findsOneWidget);
      expect(find.text('Comedy'), findsOneWidget);

      // User avatar initial
      expect(find.text('O'), findsOneWidget);
      expect(find.text('OttAdmin'), findsOneWidget);

      // Search button
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}
