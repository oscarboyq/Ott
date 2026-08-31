import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/constants/app_config.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/services/app_settings_service.dart';
import 'package:video/core/services/setup_persistence_service.dart';
import 'package:video/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:video/features/auth/presentation/pages/login_page.dart';
import 'package:video/features/auth/presentation/pages/register_page.dart';
import 'package:video/features/catalog/presentation/pages/home_page.dart';
import 'package:video/features/history/presentation/pages/history_page.dart';
import 'package:video/features/reels/presentation/pages/reels_page.dart';
import 'package:video/features/series/presentation/pages/series_details_page.dart';
import 'package:video/features/series/presentation/pages/series_episode_page.dart';
import 'package:video/features/setup/presentation/pages/setup_wizard_page.dart';
import 'package:video/features/subscription/presentation/pages/subscription_page.dart';
import 'package:video/features/video/presentation/pages/video_details_page_new.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref.onDispose(refreshNotifier.dispose);
  ref.listen<AuthState>(authProvider, (_, __) {
    refreshNotifier.value++;
  });

  String buildLoginRedirect(GoRouterState state) {
    final redirectTo = state.uri.toString();
    final loginUri = Uri(
      path: '/login',
      queryParameters: {'redirectTo': redirectTo},
    );
    return loginUri.toString();
  }

  final router = GoRouter(
    refreshListenable: refreshNotifier,
    redirect: (context, state) async {
      final isSetupRoute = state.matchedLocation == '/setup';
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      if (!AppConstants.isConfigured) {
        return isSetupRoute ? null : '/setup';
      }

      var isSetupCompleted = await SetupPersistenceService.instance
          .isSetupCompleted();

      if (!isSetupCompleted) {
        try {
          isSetupCompleted = await ref
              .read(appSettingsServiceProvider)
              .isSetupCompleted();
          if (isSetupCompleted) {
            await SetupPersistenceService.instance.markSetupCompleted();
          }
        } catch (_) {
          // Keep local setup flag authoritative if remote check fails.
        }
      }

      // Third fallback: credentials are saved AND the database tables exist
      // means the user already ran the SQL and created their admin account.
      // Mark setup done locally so we never loop back to the wizard again.
      if (!isSetupCompleted) {
        try {
          final dbReady = await ref
              .read(appSettingsServiceProvider)
              .isDatabaseReady();
          if (dbReady) {
            await SetupPersistenceService.instance
                .markSetupAwaitingConfirmation();
            isSetupCompleted = true;
          }
        } catch (_) {
          // If Supabase is unreachable, fall through to setup.
        }
      }

      if (!isSetupCompleted) {
        return isSetupRoute ? null : '/setup';
      }

      final authState = ref.read(authProvider);
      final hasInitializedAuth = authState.hasInitialized;
      final isAuthenticated = authState.isAuthenticated;

      if (isSetupRoute) {
        if (!hasInitializedAuth) {
          return null;
        }
        return isAuthenticated ? '/' : '/login';
      }

      if (!hasInitializedAuth) {
        return null;
      }

      if (!isAuthenticated && !isLoggingIn && !isRegistering) {
        return buildLoginRedirect(state);
      }

      if (isAuthenticated && (isLoggingIn || isRegistering)) {
        final redirectTo = state.uri.queryParameters['redirectTo'];
        return redirectTo ?? '/';
      }

      if (state.matchedLocation == '/admin') {
        if (!isAuthenticated) return buildLoginRedirect(state);
        if (authState.user?.isAdmin != true) return '/';
      }

      return null;
    },
    routes: <RouteBase>[
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
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupWizardPage(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
