import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/core/models/crypto_payment_model.dart';
import 'package:video/core/models/subscription_plan_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/service_providers.dart';

class CryptoCheckoutState {
  const CryptoCheckoutState({
    this.payment,
    this.loadingPlanId,
    this.isCancelling = false,
    this.error,
    this.stackTrace,
  });

  final CryptoPaymentModel? payment;
  final String? loadingPlanId;
  final bool isCancelling;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isLoading => loadingPlanId != null;
  bool get hasError => error != null;

  CryptoCheckoutState copyWith({
    CryptoPaymentModel? payment,
    bool clearPayment = false,
    String? loadingPlanId,
    bool clearLoadingPlanId = false,
    bool? isCancelling,
    Object? error,
    bool clearError = false,
    StackTrace? stackTrace,
    bool clearStackTrace = false,
  }) {
    return CryptoCheckoutState(
      payment: clearPayment ? null : (payment ?? this.payment),
      loadingPlanId: clearLoadingPlanId
          ? null
          : (loadingPlanId ?? this.loadingPlanId),
      isCancelling: isCancelling ?? this.isCancelling,
      error: clearError ? null : (error ?? this.error),
      stackTrace: clearStackTrace ? null : (stackTrace ?? this.stackTrace),
    );
  }
}

// Subscription Plans Provider
final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlanModel>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final plansData = await apiService.getSubscriptionPlans(
      includeInactive: true,
    );
    return (plansData as Iterable)
        .map(
          (item) =>
              SubscriptionPlanModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  } catch (e) {
    return [];
  }
});

// User Subscription Provider
final userSubscriptionProvider = FutureProvider<dynamic>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    return await apiService.getUserSubscription();
  } catch (e) {
    return null;
  }
});

final cryptoPaymentsProvider = FutureProvider<List<CryptoPaymentModel>>((
  ref,
) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    return await apiService.getCryptoPayments();
  } catch (e) {
    return [];
  }
});

class CryptoCheckoutNotifier extends StateNotifier<CryptoCheckoutState> {
  CryptoCheckoutNotifier(this.ref) : super(const CryptoCheckoutState());

  final Ref ref;

  Future<void> createPayment({
    required String planId,
    String payCurrency = 'usdtbsc',
  }) async {
    state = state.copyWith(
      loadingPlanId: planId,
      clearError: true,
      clearStackTrace: true,
    );
    try {
      final authState = ref.read(authProvider);
      final currentUser = authState.user;
      print('👤 Current user: ${currentUser?.id ?? 'NOT LOGGED IN'}');

      if (currentUser == null) {
        throw Exception('User is not authenticated. Please log in first.');
      }

      final apiService = ref.read(apiServiceProvider);
      final payment = await apiService.createCryptoPayment(
        planId: planId,
        payCurrency: payCurrency,
      );
      state = state.copyWith(
        payment: payment,
        clearLoadingPlanId: true,
        clearError: true,
        clearStackTrace: true,
      );
      ref.invalidate(cryptoPaymentsProvider);
    } catch (e, stack) {
      print('❌ Crypto payment creation failed: $e');
      print('Stack: $stack');
      state = state.copyWith(
        clearLoadingPlanId: true,
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> cancelPayment(String paymentId) async {
    state = state.copyWith(
      isCancelling: true,
      clearError: true,
      clearStackTrace: true,
    );
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.cancelCryptoPayment(paymentId);
      state = state.copyWith(
        clearPayment: true,
        isCancelling: false,
        clearError: true,
        clearStackTrace: true,
      );
      ref.invalidate(cryptoPaymentsProvider);
    } catch (e, stack) {
      state = state.copyWith(isCancelling: false, error: e, stackTrace: stack);
    }
  }

  void clearSelection() {
    state = state.copyWith(
      clearPayment: true,
      clearError: true,
      clearStackTrace: true,
    );
  }
}

final cryptoCheckoutProvider =
    StateNotifierProvider<CryptoCheckoutNotifier, CryptoCheckoutState>((ref) {
      return CryptoCheckoutNotifier(ref);
    });
