import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/constants/app_config.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/services/app_settings_service.dart';
import 'package:video/features/setup/presentation/pages/setup_status_error_page.dart';
import 'package:video/features/setup/presentation/pages/platform_pending_page.dart';
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
  ref.listen<AuthState>(authProvider, (_, _) {
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
      final isPending = state.matchedLocation == '/platform-pending';
      final isStatusError =
          state.matchedLocation == '/installation-unavailable';

      if (!AppConstants.isConfigured) {
        return isStatusError ? null : '/installation-unavailable';
      }

      late bool isSetupCompleted;
      try {
        // Always read Supabase, including direct /setup visits. Browser flags
        // and the old Blob lock never decide installation state.
        isSetupCompleted = await ref
            .read(appSettingsServiceProvider)
            .isSetupCompleted();
      } catch (_) {
        return isStatusError ? null : '/installation-unavailable';
      }

      if (!isSetupCompleted) {
        final auth = ref.read(authProvider);
        if (!auth.hasInitialized || !auth.isAuthenticated) {
          return isLoggingIn || isPending ? null : '/platform-pending';
        }
        try {
          final owner = await ref
              .read(appSettingsServiceProvider)
              .isInstallationOwner();
          if (owner) return isSetupRoute ? null : '/setup';
          return isPending ? null : '/platform-pending';
        } catch (_) {
          return isStatusError ? null : '/installation-unavailable';
        }
      }

      final authState = ref.read(authProvider);
      final hasInitializedAuth = authState.hasInitialized;
      final isAuthenticated = authState.isAuthenticated;

      if (isSetupRoute || isStatusError || isPending) {
        if (!hasInitializedAuth) {
          return '/login';
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
        path: '/platform-pending',
        builder: (context, state) => const PlatformPendingPage(),
      ),
      GoRoute(
        path: '/installation-unavailable',
        builder: (context, state) => const SetupStatusErrorPage(),
      ),
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
