import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:video/features/auth/presentation/pages/login_page.dart';
import 'package:video/features/auth/presentation/pages/register_page.dart';
import 'package:video/features/catalog/presentation/pages/home_page.dart';
import 'package:video/features/reels/presentation/pages/reels_page.dart';
import 'package:video/features/subscription/presentation/pages/subscription_page.dart';
import 'package:video/features/video/presentation/pages/video_details_page_new.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
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
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      // Main Routes
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/reels',
        builder: (context, state) =>
            ReelsPage(initialReelId: state.uri.queryParameters['reelId']),
      ),
      GoRoute(
        path: '/video/:videoId',
        builder: (context, state) {
          final videoId = state.pathParameters['videoId'] ?? '';
          return VideoDetailsPage(videoId: videoId);
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
});
