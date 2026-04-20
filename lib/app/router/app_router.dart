import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:video/features/auth/presentation/pages/login_page.dart';
import 'package:video/features/auth/presentation/pages/register_page.dart';
import 'package:video/features/catalog/presentation/pages/home_page.dart';
import 'package:video/features/history/presentation/pages/history_page.dart';
import 'package:video/features/reels/presentation/pages/reels_page.dart';
import 'package:video/features/series/presentation/pages/series_details_page.dart';
import 'package:video/features/series/presentation/pages/series_episode_page.dart';
import 'package:video/features/subscription/presentation/pages/subscription_page.dart';
import 'package:video/features/video/presentation/pages/video_details_page_new.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref.onDispose(refreshNotifier.dispose);
  ref.listen<AuthState>(authProvider, (_, __) {
    refreshNotifier.value++;
  });

  final router = GoRouter(
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      // Admin route guard — only admin users may access /admin
      if (state.matchedLocation == '/admin') {
        if (!isAuthenticated) return '/login';
        if (authState.user?.isAdmin != true) return '/';
      }

      if (isAuthenticated && (isLoggingIn || isRegistering)) {
        final redirectTo = state.uri.queryParameters['redirectTo'];
        return redirectTo ?? '/';
      }

      return null;
    },
    routes: <RouteBase>[
      // Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginPage(redirectTo: state.uri.queryParameters['redirectTo']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegisterPage(redirectTo: state.uri.queryParameters['redirectTo']),
      ),

      // Main Routes
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/reels',
        builder: (context, state) =>
            ReelsPage(initialReelId: state.uri.queryParameters['reelId']),
      ),
      GoRoute(
        path: '/video/:videoId',
        builder: (context, state) {
          final videoId = state.pathParameters['videoId'] ?? '';
          final autoPlay = state.uri.queryParameters['autoplay'] == 'true';
          return VideoDetailsPage(videoId: videoId, autoPlay: autoPlay);
        },
      ),
      GoRoute(
        path: '/series/:seriesId',
        builder: (context, state) {
          final seriesId = state.pathParameters['seriesId'] ?? '';
          return SeriesDetailsPage(seriesId: seriesId);
        },
      ),
      GoRoute(
        path: '/series/:seriesId/episode/:episodeId',
        builder: (context, state) {
          final seriesId = state.pathParameters['seriesId'] ?? '';
          final episodeId = state.pathParameters['episodeId'] ?? '';
          return SeriesEpisodePage(seriesId: seriesId, episodeId: episodeId);
        },
      ),
      GoRoute(
        path: '/plans',
        builder: (context, state) => const SubscriptionPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardPage(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
