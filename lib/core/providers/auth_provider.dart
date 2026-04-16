import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/core/models/user_model.dart';
import 'package:video/core/providers/service_providers.dart';

// Auth State Notifier
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? accessToken;
  final String? refreshToken;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? accessToken,
    String? refreshToken,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this.ref) : super(const AuthState()) {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;

      if (event == AuthChangeEvent.signedOut) {
        state = const AuthState();
        ref.read(httpClientProvider).removeAuthToken();
        return;
      }

      checkAuthStatus();
    });

    checkAuthStatus();
  }

  final Ref ref;
  late final StreamSubscription _authSubscription;

  Future<UserModel> _buildUserModel({
    required User supabaseUser,
    required String fallbackEmail,
    required String fallbackUsername,
  }) async {
    bool isAdmin = false;
    bool isPremium = false;
    DateTime? premiumExpiresAt;

    try {
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('is_admin')
          .eq('id', supabaseUser.id)
          .maybeSingle();
      isAdmin = profile?['is_admin'] as bool? ?? false;
      debugPrint('is_admin fetched: $isAdmin (profile: $profile)');
    } catch (e) {
      debugPrint('Failed to fetch is_admin: $e');
    }

    try {
      final subscriptions = await Supabase.instance.client
          .from('user_subscriptions')
          .select('expires_at')
          .eq('is_active', true)
          .order('expires_at', ascending: false)
          .limit(1);

      if (subscriptions.isNotEmpty) {
        final expiresAtRaw = subscriptions.first['expires_at'] as String?;
        final expiresAt = expiresAtRaw == null
            ? null
            : DateTime.tryParse(expiresAtRaw);

        if (expiresAt != null && expiresAt.isAfter(DateTime.now())) {
          isPremium = true;
          premiumExpiresAt = expiresAt;
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch premium status: $e');
    }

    return UserModel(
      id: supabaseUser.id,
      email: supabaseUser.email ?? fallbackEmail,
      username:
          supabaseUser.userMetadata?['username'] as String? ?? fallbackUsername,
      isPremium: isPremium,
      isAdmin: isAdmin,
      createdAt: DateTime.now(),
      premiumExpiresAt: premiumExpiresAt,
    );
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Use the Supabase SDK — calls /auth/v1/token?grant_type=password
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final session = response.session;
      final supabaseUser = response.user;

      if (session == null || supabaseUser == null) {
        throw Exception('Login failed: no session returned');
      }

      // Persist tokens
      final storageService = ref.read(secureStorageProvider);
      await storageService.saveAccessToken(session.accessToken);
      if (session.refreshToken != null) {
        await storageService.saveRefreshToken(session.refreshToken!);
      }

      // Set bearer token for non-auth API calls (videos, watchlist, etc.)
      ref.read(httpClientProvider).setAuthToken(session.accessToken);

      final userModel = await _buildUserModel(
        supabaseUser: supabaseUser,
        fallbackEmail: email,
        fallbackUsername: email.split('@').first,
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: userModel,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Use the Supabase SDK — calls /auth/v1/signup
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        throw Exception('Registration failed');
      }

      final session = response.session;
      if (session != null) {
        // Auto-confirmed — user is logged in immediately
        final storageService = ref.read(secureStorageProvider);
        await storageService.saveAccessToken(session.accessToken);
        if (session.refreshToken != null) {
          await storageService.saveRefreshToken(session.refreshToken!);
        }
        ref.read(httpClientProvider).setAuthToken(session.accessToken);

        final userModel = await _buildUserModel(
          supabaseUser: supabaseUser,
          fallbackEmail: email,
          fallbackUsername: username,
        );

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: userModel,
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
      } else {
        // Email confirmation required
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Check your email to confirm your account.',
        );
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      // Use the Supabase SDK session — no network call needed
      final currentSession = Supabase.instance.client.auth.currentSession;
      final supabaseUser = Supabase.instance.client.auth.currentUser;

      if (currentSession != null && supabaseUser != null) {
        ref.read(httpClientProvider).setAuthToken(currentSession.accessToken);

        final userModel = await _buildUserModel(
          supabaseUser: supabaseUser,
          fallbackEmail: supabaseUser.email ?? '',
          fallbackUsername: (supabaseUser.email ?? '').split('@').first,
        );

        state = state.copyWith(
          isAuthenticated: true,
          user: userModel,
          accessToken: currentSession.accessToken,
          refreshToken: currentSession.refreshToken,
        );
      }
    } catch (e) {
      state = state.copyWith(isAuthenticated: false);
    }
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } finally {
      // Always clear local state regardless of server response
      await ref.read(secureStorageProvider).deleteAccessToken();
      await ref.read(secureStorageProvider).deleteRefreshToken();
      ref.read(httpClientProvider).removeAuthToken();
      state = const AuthState();
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

// Auth Provider
final authProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref);
});

// Computed provider for authentication status
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

// Computed provider for current user model
final currentUserModelProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
