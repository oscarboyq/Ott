class AppConstants {
  // ============================================================
  // SUPABASE CONFIGURATION (Primary Backend)
  // ============================================================
  static const String supabaseUrl = 'https://mornbhixlbbebaoobsng.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vcm5iaGl4bGJiZWJhb29ic25nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxNTUyODEsImV4cCI6MjA5MTczMTI4MX0.Dzq7q8Kvb5fU6iuCRrHzEoDxVtfqXDnbGYcvQ1HmjIE';
  // Keep this secret! Only use in backend
  // static const String supabaseServiceRoleKey = 'YOUR_SERVICE_ROLE_KEY';

  // ============================================================
  // API Configuration
  // ============================================================
  static const String baseUrl =
      'https://mornbhixlbbebaoobsng.supabase.co/rest/v1';
  static const String apiV1 = '/rest/v1';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Auth Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String refreshTokenEndpoint = '/auth/refresh';
  static const String logoutEndpoint = '/auth/logout';
  static const String userProfileEndpoint = '/auth/profile';

  // Video Endpoints
  static const String videosEndpoint = '/videos';
  static const String videoDetailsEndpoint = '/videos/:videoId';
  static const String searchVideosEndpoint = '/videos/search';
  static const String videoCatalogEndpoint = '/videos/catalog';

  // Watchlist Endpoints
  static const String watchlistEndpoint = '/watchlist';
  static const String watchlistAddEndpoint = '/watchlist/add';
  static const String watchlistRemoveEndpoint = '/watchlist/remove';

  // Subscription Endpoints
  static const String subscriptionPlansEndpoint = '/subscriptions/plans';
  static const String userSubscriptionEndpoint = '/subscriptions/user';
  static const String upgradeSubscriptionEndpoint = '/subscriptions/upgrade';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userPreferencesKey = 'user_preferences';
  static const String watchlistCacheKey = 'watchlist_cache';
  static const String videoCatalogCacheKey = 'video_catalog_cache';

  // App Configuration
  static const int cacheDurationMinutes = 60;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
