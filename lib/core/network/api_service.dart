import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:video/core/constants/app_config.dart';
import 'package:video/core/exceptions/app_exception.dart';
import 'package:video/core/models/auth_response_model.dart';
import 'package:video/core/models/crypto_payment_model.dart';
import 'package:video/core/models/user_model.dart';
import 'package:video/core/network/http_client.dart';

class ApiService {
  final HttpClient _httpClient;

  ApiService(this._httpClient);

  supabase.SupabaseClient get _supabase => supabase.Supabase.instance.client;

  Future<List<dynamic>> _mergeVideoRatingStatsIntoList(
    List<dynamic> videos,
  ) async {
    if (videos.isEmpty) {
      return videos;
    }

    final videoRows = videos.whereType<Map<String, dynamic>>().toList(
      growable: false,
    );
    final videoIds = videoRows
        .map((video) => video['id'] as String?)
        .whereType<String>()
        .toList(growable: false);

    if (videoIds.isEmpty) {
      return videos;
    }

    final ratingsData = await _supabase
        .from('video_ratings')
        .select('video_id, rating')
        .inFilter('video_id', videoIds);

    final ratingsByVideo = <String, List<double>>{};
    for (final item in ratingsData as List<dynamic>) {
      final row = item as Map<String, dynamic>;
      final videoId = row['video_id'] as String?;
      final rating = (row['rating'] as num?)?.toDouble();
      if (videoId == null || rating == null) {
        continue;
      }
      ratingsByVideo.putIfAbsent(videoId, () => <double>[]).add(rating);
    }

    return videoRows
        .map((video) {
          final videoId = video['id'] as String?;
          if (videoId == null) {
            return video;
          }

          final ratings = ratingsByVideo[videoId];
          if (ratings == null || ratings.isEmpty) {
            return {...video, 'rating': 0.0, 'rating_count': 0};
          }

          final total = ratings.fold<double>(0, (sum, value) => sum + value);
          final average = double.parse(
            (total / ratings.length).toStringAsFixed(1),
          );

          return {...video, 'rating': average, 'rating_count': ratings.length};
        })
        .toList(growable: false);
  }

  Future<dynamic> _mergeVideoRatingStatsIntoItem(dynamic video) async {
    if (video is! Map<String, dynamic>) {
      return video;
    }

    final mergedList = await _mergeVideoRatingStatsIntoList([video]);
    return mergedList.isEmpty ? video : mergedList.first;
  }

  Future<String> _getValidSupabaseAccessToken() async {
    var session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;

    print('🔐 Current session available: ${session != null}');
    print('🔐 Current user available: ${user != null}');

    if (session == null || user == null) {
      throw AuthException('User is not authenticated. Please log in again.');
    }

    final nowInSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = session.expiresAt;
    final expiresSoon = expiresAt != null && (expiresAt - nowInSeconds) < 60;

    print('🔐 Session expired: ${session.isExpired}');
    print('🔐 Session expiresAt: $expiresAt');

    if (session.isExpired || expiresSoon) {
      print('🔄 Refreshing Supabase session before payment request...');
      final refreshedAuth = await _supabase.auth.refreshSession();
      session = refreshedAuth.session;

      if (session == null || session.accessToken.isEmpty) {
        throw AuthException('Session refresh failed. Please log in again.');
      }
    }

    return session.accessToken;
  }

  // Auth APIs
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        AppConstants.loginEndpoint,
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200 && response.data != null) {
        return AuthResponseModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw ServerException('Login failed', response.statusCode ?? 500);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<AuthResponseModel> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        AppConstants.registerEndpoint,
        data: {'email': email, 'username': username, 'password': password},
      );

      if (response.statusCode == 201 && response.data != null) {
        return AuthResponseModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw ServerException('Registration failed', response.statusCode ?? 500);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<UserModel> getUserProfile() async {
    try {
      final response = await _httpClient.get(AppConstants.userProfileEndpoint);

      if (response.statusCode == 200 && response.data != null) {
        return UserModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw ServerException(
        'Failed to fetch profile',
        response.statusCode ?? 500,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    try {
      final response = await _httpClient.post(
        AppConstants.refreshTokenEndpoint,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        return AuthResponseModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw ServerException('Token refresh failed', response.statusCode ?? 500);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _httpClient.post(AppConstants.logoutEndpoint);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  // Video APIs - Using Supabase SDK PostgREST (avoids CORS issues on web)
  Future<List<dynamic>> getVideoCatalog({
    int page = 1,
    int limit = 20,
    String? genre,
    bool includeReels = false,
    bool reelsOnly = false,
  }) async {
    try {
      final offset = (page - 1) * limit;
      // Apply filter before ordering/ranging (filter must come before transform)
      var filterBuilder = _supabase.from('videos').select();
      if (reelsOnly) {
        filterBuilder = filterBuilder.eq('is_reel', true);
      } else if (!includeReels) {
        filterBuilder = filterBuilder.eq('is_reel', false);
      }
      if (genre != null) {
        filterBuilder = filterBuilder.eq('category', genre);
      }
      final data = await filterBuilder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return _mergeVideoRatingStatsIntoList(data as List<dynamic>);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<dynamic> getVideoDetails(String videoId) async {
    try {
      final data = await _supabase
          .from('videos')
          .select()
          .eq('id', videoId)
          .single();
      return _mergeVideoRatingStatsIntoItem(data);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<int?> getCurrentUserVideoRating(String videoId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return null;
      }

      final data = await _supabase
          .from('video_ratings')
          .select('rating')
          .eq('video_id', videoId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return (data['rating'] as num?)?.toInt();
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<Map<String, dynamic>> getVideoRatingStats(String videoId) async {
    try {
      final data = await _supabase
          .from('video_ratings')
          .select('rating')
          .eq('video_id', videoId);

      final ratings = (data as List<dynamic>)
          .map(
            (item) =>
                ((item as Map<String, dynamic>)['rating'] as num?)?.toDouble(),
          )
          .whereType<double>()
          .toList(growable: false);

      if (ratings.isEmpty) {
        return {'average': 0.0, 'count': 0};
      }

      final total = ratings.fold<double>(0, (sum, rating) => sum + rating);
      final average = double.parse((total / ratings.length).toStringAsFixed(1));

      return {'average': average, 'count': ratings.length};
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<void> submitVideoRating({
    required String videoId,
    required int rating,
  }) async {
    try {
      if (rating < 1 || rating > 10) {
        throw ValidationException('Rating must be between 1 and 10.');
      }

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw AuthException('Please sign in to rate this video.');
      }

      final video = await _supabase
          .from('videos')
          .select('id, is_free')
          .eq('id', videoId)
          .maybeSingle();

      if (video == null) {
        throw ValidationException('Video not found.');
      }

      final isFreeVideo = (video['is_free'] as bool?) ?? true;
      if (!isFreeVideo) {
        final activeSubscription = await _supabase
            .from('user_subscriptions')
            .select('id, expires_at')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .order('expires_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final expiresAt = activeSubscription?['expires_at'] as String?;
        final hasPremiumAccess =
            expiresAt != null &&
            (DateTime.tryParse(expiresAt)?.isAfter(DateTime.now()) ?? false);

        if (!hasPremiumAccess) {
          throw AuthException(
            'Premium membership is required to rate this video.',
          );
        }
      }

      final existingRating = await _supabase
          .from('video_ratings')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingRating != null) {
        throw ValidationException('You have already rated this video.');
      }

      await _supabase.from('video_ratings').insert({
        'video_id': videoId,
        'user_id': user.id,
        'rating': rating,
      });
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<List<dynamic>> searchVideos({
    required String query,
    int page = 1,
    int limit = 20,
    bool includeReels = false,
    bool reelsOnly = false,
  }) async {
    try {
      final offset = (page - 1) * limit;
      var filterBuilder = _supabase
          .from('videos')
          .select()
          .ilike('title', '%$query%');
      if (reelsOnly) {
        filterBuilder = filterBuilder.eq('is_reel', true);
      } else if (!includeReels) {
        filterBuilder = filterBuilder.eq('is_reel', false);
      }
      final data = await filterBuilder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return _mergeVideoRatingStatsIntoList(data as List<dynamic>);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  // Watchlist APIs - Using Supabase SDK
  Future<List<dynamic>> getWatchlist() async {
    try {
      final data = await _supabase
          .from('watchlist')
          .select(
            '*,videos:video_id(id,title,thumbnail_url,category,rating,is_free)',
          )
          .order('added_at', ascending: false);
      return data as List<dynamic>;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<void> addToWatchlist(String videoId) async {
    try {
      await _supabase.from('watchlist').insert({'video_id': videoId});
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<void> removeFromWatchlist(String watchlistId) async {
    try {
      await _supabase.from('watchlist').delete().eq('id', watchlistId);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  // Subscription APIs - Using Supabase SDK
  Future<List<dynamic>> getSubscriptionPlans({
    bool includeInactive = false,
  }) async {
    try {
      var query = _supabase.from('subscription_plans').select();
      if (!includeInactive) {
        query = query.eq('is_active', true);
      }

      final data = await query
          .order('is_active', ascending: false)
          .order('monthly_price', ascending: true)
          .order('name', ascending: true);
      return data as List<dynamic>;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<dynamic> getUserSubscription() async {
    try {
      final data = await _supabase
          .from('user_subscriptions')
          .select('*,plan:plan_id(id,name,monthly_price,features)')
          .eq('is_active', true)
          .maybeSingle();
      return data;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<dynamic> upgradeSubscription(String planId) async {
    try {
      final data = await _supabase
          .from('user_subscriptions')
          .insert({
            'plan_id': planId,
            'auto_renew': true,
            'expires_at': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String(),
          })
          .select()
          .single();
      return data;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<CryptoPaymentModel> createCryptoPayment({
    required String planId,
    String payCurrency = 'usdtbsc',
  }) async {
    try {
      final accessToken = await _getValidSupabaseAccessToken();

      print('🔐 Invoking nowpayments-create-payment...');
      print('📦 Payload: planId=$planId, payCurrency=$payCurrency');

      final response = await _supabase.functions.invoke(
        'nowpayments-create-payment',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {'planId': planId, 'payCurrency': payCurrency},
      );

      print('✅ Function response status: ${response.status}');
      print('📄 Function response data: ${response.data}');

      final data = response.data;
      if (response.status >= 400) {
        throw ServerException(
          data is Map && data['error'] != null
              ? data['error'].toString()
              : 'Failed to create crypto payment',
          response.status,
        );
      }

      if (data is! Map) {
        throw UnknownException('Unexpected crypto payment response');
      }

      return CryptoPaymentModel.fromJson(Map<String, dynamic>.from(data));
    } on supabase.AuthException catch (e) {
      throw AuthException(e.message);
    } on supabase.FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : details is Map && details['message'] != null
          ? details['message'].toString()
          : e.toString();
      throw ServerException(message, e.status);
    } on AppException {
      rethrow;
    } catch (e) {
      print('❌ Exception in createCryptoPayment: $e');
      throw UnknownException(e.toString());
    }
  }

  Future<void> cancelCryptoPayment(String paymentId) async {
    try {
      final accessToken = await _getValidSupabaseAccessToken();

      final response = await _supabase.functions.invoke(
        'nowpayments-cancel-payment',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {'paymentId': paymentId},
      );

      if (response.status >= 400) {
        final data = response.data;
        throw ServerException(
          data is Map && data['error'] != null
              ? data['error'].toString()
              : 'Failed to cancel payment',
          response.status,
        );
      }
    } on supabase.AuthException catch (e) {
      throw AuthException(e.message);
    } on supabase.FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : details is Map && details['message'] != null
          ? details['message'].toString()
          : e.toString();
      throw ServerException(message, e.status);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  Future<List<CryptoPaymentModel>> getCryptoPayments() async {
    try {
      final data = await _supabase
          .from('payments')
          .select()
          .eq('provider', 'nowpayments')
          .order('created_at', ascending: false)
          .limit(10);

      return (data as Iterable)
          .map(
            (item) => CryptoPaymentModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }
}
