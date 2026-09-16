import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video/app/app.dart';
import 'package:video/app/theme/app_theme.dart';
import 'package:video/core/models/user_model.dart';
import 'package:video/core/models/video_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/series_catalog_provider.dart';
import 'package:video/core/providers/video_catalog_provider.dart';
import 'package:video/core/providers/watch_history_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:video/core/services/app_settings_service.dart';
import 'package:video/core/models/platform_branding.dart';
import 'package:video/core/providers/branding_provider.dart';
import 'package:video/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:video/features/auth/presentation/pages/login_page.dart';
import 'package:video/features/catalog/presentation/pages/home_page.dart';
import 'package:video/features/reels/presentation/pages/reels_page.dart';
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

    testWidgets(
      'renders readable platform name and username in light theme (not white)',
      (WidgetTester tester) async {
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
              theme: AppTheme.lightTheme(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final brandFinder = find.text('StreamOTT');
        expect(brandFinder, findsOneWidget);
        final brandText = tester.widget<Text>(brandFinder);
        expect(brandText.style?.color, const Color(0xFF0F172A));
        expect(brandText.style?.color, isNot(Colors.white));

        final userFinder = find.text('OttAdmin');
        expect(userFinder, findsOneWidget);
        final userText = tester.widget<Text>(userFinder);
        expect(userText.style?.color, const Color(0xFF475569));
        expect(userText.style?.color, isNot(Colors.white));
        expect(userText.style?.color, isNot(Colors.white70));

        // Reels button in navbar is visible and uses light theme primary text
        final reelsNavFinder = find.widgetWithText(TextButton, 'Reels');
        expect(reelsNavFinder, findsOneWidget);
      },
    );

    testWidgets(
      'ReelsPage adapts to light theme without hardcoded white text on empty state',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final router = GoRouter(
          initialLocation: '/reels',
          routes: [
            GoRoute(
              path: '/reels',
              builder: (context, state) => const ReelsPage(),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              reelsCatalogProvider.overrideWith(
                (ref) => Future.value(<VideoModel>[]),
              ),
              authProvider.overrideWith(
                (ref) => MockAuthStateNotifier(
                  const AuthState(
                    hasInitialized: true,
                    isAuthenticated: false,
                    user: null,
                  ),
                ),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final emptyTitleFinder = find.text('No reels yet');
        expect(emptyTitleFinder, findsOneWidget);
        final emptyText = tester.widget<Text>(emptyTitleFinder);
        expect(emptyText.style?.color, const Color(0xFF0F172A));
        expect(emptyText.style?.color, isNot(Colors.white));

        final scaffoldFinder = find.byType(Scaffold);
        expect(scaffoldFinder, findsOneWidget);
        final scaffold = tester.widget<Scaffold>(scaffoldFinder);
        expect(scaffold.backgroundColor, const Color(0xFFF8FAFC));
      },
    );

    testWidgets(
      'BunnyVideoPicker dynamically adapts surface, border, and text to light theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: BunnyVideoPicker(
                file: XFile('sample_video.mp4'),
                fileSize: 15 * 1024 * 1024,
                error: null,
                enabled: true,
                onPick: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Selected filename must use light theme text primary, not white
        final fileNameFinder = find.text('sample_video.mp4');
        expect(fileNameFinder, findsOneWidget);
        final fileNameText = tester.widget<Text>(fileNameFinder);
        expect(fileNameText.style?.color, const Color(0xFF0F172A));
        expect(fileNameText.style?.color, isNot(Colors.white));

        // Outer container should resolve to context.surfaceBg (#FFFFFF in light theme)
        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  const Color(0xFFFFFFFF),
        );
        expect(containerFinder, findsOneWidget);

        // Verify border is context.borderCol (#E2E8F0 in light theme), not hardcoded #243247
        final container = tester.widget<Container>(containerFinder);
        final boxDecoration = container.decoration as BoxDecoration;
        expect(
          (boxDecoration.border as Border).top.color,
          const Color(0xFFE2E8F0),
        );
        expect(
          (boxDecoration.border as Border).top.color,
          isNot(const Color(0xFF243247)),
        );
      },
    );

    testWidgets(
      'BunnyVideoPicker dynamically adapts surface, border, and text to dark theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme(),
            home: Scaffold(
              body: BunnyVideoPicker(
                file: XFile('sample_video.mp4'),
                fileSize: 15 * 1024 * 1024,
                error: null,
                enabled: true,
                onPick: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fileNameFinder = find.text('sample_video.mp4');
        expect(fileNameFinder, findsOneWidget);
        final fileNameText = tester.widget<Text>(fileNameFinder);
        expect(fileNameText.style?.color, Colors.white);

        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  const Color(0xFF101826),
        );
        expect(containerFinder, findsOneWidget);
      },
    );

    testWidgets(
      'AdminImageUploadField displays high-contrast dark text and spinner while uploading in light theme',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: AdminImageUploadField(
                label: 'Thumbnail URL *',
                controller: controller,
                hint: 'https://...',
                isUploading: true,
                onUpload: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        final uploadingTextFinder = find.text('Uploading...');
        expect(uploadingTextFinder, findsOneWidget);
        final uploadingText = tester.widget<Text>(uploadingTextFinder);
        expect(uploadingText.style?.color, const Color(0xFF0F172A));
        expect(uploadingText.style?.color, isNot(Colors.white));

        final spinnerFinder = find.byType(CircularProgressIndicator);
        expect(spinnerFinder, findsOneWidget);
        final spinner = tester.widget<CircularProgressIndicator>(spinnerFinder);
        expect(
          (spinner.valueColor as AlwaysStoppedAnimation<Color>).value,
          const Color(0xFF0F172A),
        );
      },
    );

    testWidgets(
      'SettingsSection renders professional categorized OTT tabs and removes crypto payment API fields',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              allSettingsProvider.overrideWith(
                (ref) async => {
                  SettingKeys.appName: 'StreamOTT',
                  SettingKeys.appTagline: 'Stream unlimited entertainment',
                  SettingKeys.appLogoUrl: '',
                  SettingKeys.appFaviconUrl: '',
                  SettingKeys.defaultStreamQuality: '1080p Full HD',
                },
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              home: const Scaffold(
                body: SettingsSection(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify Header & Tab Switcher exist
        expect(find.text('Platform Configuration & Policies'), findsOneWidget);
        expect(find.text('Branding & Identity'), findsOneWidget);
        expect(find.text('Playback & Streaming'), findsOneWidget);
        expect(find.text('Catalog & Features'), findsOneWidget);
        expect(find.text('Legal & Support'), findsOneWidget);
        expect(find.text('Infrastructure & Security'), findsOneWidget);

        // 2. Verify Crypto Payment API fields are NOT present in the UI
        expect(find.text('NOWPayments (Crypto Payments)'), findsNothing);
        expect(find.text('Your NOWPayments API key'), findsNothing);
        expect(find.text('NOWPAYMENTS_API_KEY=<your key>'), findsNothing);
        expect(find.text('Webhook verification secret'), findsNothing);

        // 3. Verify Default Tab (Branding) content
        expect(find.text('Platform Identity & Visual Assets'), findsOneWidget);
        expect(find.text('Brand Tagline / Slogan'), findsOneWidget);
        expect(find.text('Website Navigation Bar Logo'), findsOneWidget);
        expect(find.text('Live Navigation Bar Preview'), findsOneWidget);

        // 4. Switch to Playback & Streaming tab
        await tester.tap(find.text('Playback & Streaming'));
        await tester.pumpAndSettle();

        expect(find.text('Streaming Engine & Video Player Policies'), findsOneWidget);
        expect(find.text('Default Streaming Quality Profile'), findsOneWidget);
        expect(find.text('Autoplay Next Episode in Series'), findsOneWidget);

        // Verify quality dropdown includes 480p SD and 360p Low
        await tester.tap(find.byType(DropdownButton<String>).first);
        await tester.pumpAndSettle();
        expect(find.text('480p SD'), findsWidgets);
        expect(find.text('360p Low'), findsWidgets);
        await tester.tap(find.text('480p SD').last);
        await tester.pumpAndSettle();

        // 5. Switch to Infrastructure & Security tab
        await tester.tap(find.text('Infrastructure & Security'));
        await tester.pumpAndSettle();

        expect(find.text('Zero Client-Side Secret Exposure Architecture'), findsOneWidget);
        expect(find.text('Active Server-Side Gateway Integrations'), findsOneWidget);
      },
    );

    testWidgets(
      'HomePage and LoginPage display custom Brand Tagline when configured',
      (WidgetTester tester) async {
        const customBranding = PlatformBranding(
          name: 'CineSphere',
          tagline: 'Stream unlimited movies, series',
        );

        // 1. Verify LoginPage renders custom tagline
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              platformBrandingProvider.overrideWithValue(customBranding),
            ],
            child: const MaterialApp(
              home: LoginPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('CineSphere'), findsAtLeastNWidgets(1));
        expect(
          find.text('Stream unlimited movies, series'),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'SettingsSection Live Navigation Bar Preview renders both custom logo and platform name',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SettingsSection(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Default: renders StreamOTT and Default badge
        expect(find.text('Live Navigation Bar Preview'), findsOneWidget);
        expect(find.text('Default'), findsOneWidget);

        // Enter a logo URL in the direct URL TextField
        final urlFieldFinder = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              (widget.decoration?.hintText?.contains('Or enter direct Logo Image URL') ?? false),
        );
        expect(urlFieldFinder, findsOneWidget);
        await tester.enterText(urlFieldFinder, 'https://example.com/custom_logo.png');
        await tester.pump();

        // Custom logo: now renders Custom Logo badge AND platform name!
        expect(find.text('Custom Logo'), findsOneWidget);
        expect(find.text('StreamOTT'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'HomePage and VideoDetails display playback streaming profile and hero autoplay badges',
      (WidgetTester tester) async {
        final sampleVideo = VideoModel(
          id: 'test-vid-1',
          title: 'Cinematic Masterpiece',
          description: 'A visual spectacle.',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/stream.mp4',
          genre: 'Action',
          rating: 4.9,
          ratingCount: 500,
          duration: 7200,
          viewCount: 20000,
          requiresPremium: false,
          isFeatured: true,
          releaseDate: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
        );

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
                      email: 'viewer@streamott.com',
                      username: 'Viewer',
                      isAdmin: false,
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
              allSettingsProvider.overrideWith(
                (ref) => Future.value({
                  SettingKeys.defaultStreamQuality: '1080p Full HD',
                  SettingKeys.bufferProfile: 'Aggressive Preload (Fast Start)',
                  SettingKeys.autoplayHeroTrailers: 'true',
                }),
              ),
            ],
            child: const MaterialApp(
              home: HomePage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Expect hero preview autoplay badge
        expect(find.text('PREVIEW AUTOPLAY'), findsOneWidget);
      },
    );

    testWidgets(
      'HeroBanner preview is permanently muted with no sound toggle on/off button',
      (WidgetTester tester) async {
        final sampleVideo = VideoModel(
          id: 'hero-test-1',
          title: 'Hero Muted Video',
          description: 'A test video for muted auto preview',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          videoUrl: 'https://vz-12345.b-cdn.net/video-guid-1/playlist.m3u8',
          genre: 'Action',
          rating: 8.5,
          ratingCount: 10,
          duration: 3600,
          viewCount: 100,
          requiresPremium: false,
          isFeatured: true,
          releaseDate: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
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
              allSettingsProvider.overrideWith(
                (ref) => Future.value({
                  SettingKeys.autoplayHeroTrailers: 'true',
                  SettingKeys.bunnyLibraryId: '12345',
                }),
              ),
            ],
            child: const MaterialApp(
              home: HomePage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('PREVIEW AUTOPLAY'), findsOneWidget);

        // Find the MouseRegion for Hero Banner
        final heroMouseRegion = tester.widget<MouseRegion>(
          find.byWidgetPredicate(
            (w) => w is MouseRegion && w.onEnter != null && w.onExit != null,
          ).first,
        );

        // Trigger onEnter
        heroMouseRegion.onEnter?.call(PointerEnterEvent());
        await tester.pump();

        // Advance past hover debounce timer (600ms)
        await tester.pump(const Duration(milliseconds: 700));

        // Now preview is playing
        expect(find.text('PREVIEW PLAYING'), findsOneWidget);
        expect(find.text('MUTED PREVIEW'), findsOneWidget);

        // Ensure no sound switch / toggle exists in the UI
        expect(find.textContaining('Click for sound'), findsNothing);
        expect(find.textContaining('Click to mute'), findsNothing);
        expect(find.textContaining('Sound On'), findsNothing);
      },
    );

    testWidgets(
      'Specific catalog genre view uses real OTT responsive grid layout without oversized cards',
      (WidgetTester tester) async {
        final actionVideo = VideoModel(
          id: 'action-1',
          title: 'Action Movie Hit',
          description: 'High octane thriller',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          genre: 'Action',
          rating: 9.0,
          ratingCount: 150,
          duration: 7200,
          viewCount: 5000,
          requiresPremium: false,
          isFeatured: true,
          releaseDate: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoCatalogProvider.overrideWith(
                (ref) => MockVideoCatalogNotifier(
                  VideoCatalogState(
                    videos: [actionVideo],
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
              allSettingsProvider.overrideWith(
                (ref) => Future.value({}),
              ),
            ],
            child: const MaterialApp(
              home: HomePage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap the Action genre chip
        final actionChip = find.widgetWithText(GestureDetector, 'Action');
        await tester.tap(actionChip);
        await tester.pumpAndSettle();

        // Verify the category heading displays
        expect(find.text('Action (1)'), findsOneWidget);

        // Verify that the grid uses SliverGridDelegateWithMaxCrossAxisExtent
        final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        expect(grid.gridDelegate, isA<SliverGridDelegateWithMaxCrossAxisExtent>());
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
        expect(delegate.maxCrossAxisExtent, 200);
        expect(delegate.childAspectRatio, 0.67);
      },
    );
  });
}
