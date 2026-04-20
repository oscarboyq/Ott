import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video/core/models/crypto_payment_model.dart';
import 'package:video/core/models/subscription_plan_model.dart';
import 'package:video/core/providers/auth_provider.dart';
import 'package:video/core/providers/subscription_provider.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  static const Color _currencyBaseColor = Color(0xFF5AE2B0);

  bool _isUpcomingPlan(SubscriptionPlanModel plan) {
    return !plan.isActive ||
        plan.tier == SubscriptionTier.platinum ||
        (plan.monthlyPrice == 0 && plan.name.toLowerCase() != 'free');
  }

  String _formatPayAmount(CryptoPaymentModel payment) {
    final amount = payment.payAmount;
    if (amount == null) {
      return 'Pending';
    }

    final normalized = amount.toStringAsFixed(8);
    return normalized.contains('.')
        ? normalized
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '')
        : normalized;
  }

  Widget _buildCurrencyText(String? payCurrency) {
    final normalized = (payCurrency ?? 'usdtbsc').toLowerCase();
    if (normalized == 'usdtbsc') {
      return RichText(
        text: const TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: 'USDT',
              style: TextStyle(
                color: _currencyBaseColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            WidgetSpan(child: SizedBox(width: 6)),
            TextSpan(
              text: 'bsc',
              style: TextStyle(
                color: Color(0xFF8EA0B8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      normalized.toUpperCase(),
      style: const TextStyle(
        color: _currencyBaseColor,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  String _checkoutErrorMessage(Object error) {
    final rawMessage = error.toString();
    if (rawMessage.startsWith('UnknownException: ')) {
      return rawMessage.substring('UnknownException: '.length);
    }
    if (rawMessage.startsWith('ServerException: ')) {
      return rawMessage.substring('ServerException: '.length);
    }
    return rawMessage;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final cryptoCheckoutState = ref.watch(cryptoCheckoutProvider);
    final cryptoPaymentsAsync = ref.watch(cryptoPaymentsProvider);
    final latestPendingPayment = cryptoPaymentsAsync.maybeWhen(
      data: (payments) {
        for (final payment in payments) {
          if (payment.isPending || payment.isFinished) {
            return payment;
          }
        }
        return null;
      },
      orElse: () => null,
    );
    final selectedPayment = cryptoCheckoutState.payment ?? latestPendingPayment;
    final hasPendingPayment = selectedPayment?.isPending == true;
    final hasCompletedPayment = selectedPayment?.isFinished == true;
    final hasPremiumAccess = authState.user?.isPremium == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Premium Plans')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFF070B12),
              Color(0xFF0B1019),
              Color(0xFF070B12),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFFF05454),
                          Color(0xFF7A2638),
                          Color(0xFF2B1420),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Premium unlocks the paid side of your catalog.',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          authState.isAuthenticated
                              ? 'Pay with USDT on BSC to unlock premium titles and playback.'
                              : 'Create an account first, then choose a plan to unlock premium content.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (authState.isAuthenticated) ...<Widget>[
                          const SizedBox(height: 12),
                          const Text(
                            'This flow currently creates a one-time crypto payment. When the blockchain payment is confirmed, premium access is activated automatically.',
                          ),
                        ],
                        if (!authState.isAuthenticated) ...<Widget>[
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              FilledButton(
                                onPressed: () {
                                  final registerUri = Uri(
                                    path: '/register',
                                    queryParameters: {'redirectTo': '/plans'},
                                  );
                                  context.go(registerUri.toString());
                                },
                                child: const Text('Create Account'),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  final loginUri = Uri(
                                    path: '/login',
                                    queryParameters: {'redirectTo': '/plans'},
                                  );
                                  context.go(loginUri.toString());
                                },
                                child: const Text('Sign In'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selectedPayment != null) ...<Widget>[
                    const SizedBox(height: 22),
                    _CryptoPaymentPanel(
                      payment: selectedPayment,
                      currencyText: _buildCurrencyText(
                        selectedPayment.payCurrency,
                      ),
                      payAmountText: _formatPayAmount(selectedPayment),
                      isCancelling: cryptoCheckoutState.isCancelling,
                      onCopy: (label, value) async {
                        await Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$label copied')),
                        );
                      },
                      onRefresh: () async {
                        ref.invalidate(cryptoPaymentsProvider);
                        await ref.read(authProvider.notifier).checkAuthStatus();
                      },
                      onCancel: selectedPayment.isPending
                          ? () async {
                              await ref
                                  .read(cryptoCheckoutProvider.notifier)
                                  .cancelPayment(selectedPayment.id);
                            }
                          : null,
                    ),
                  ],
                  if (cryptoCheckoutState.hasError) ...<Widget>[
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B1420),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF05454)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFF05454),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _checkoutErrorMessage(cryptoCheckoutState.error!),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  plansAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load plans: $error',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    data: (plans) {
                      if (plans.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No subscription plans available.'),
                        );
                      }

                      return LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final bool stacked = constraints.maxWidth < 840;

                              if (stacked) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: plans
                                      .map(
                                        (plan) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 18,
                                          ),
                                          child: _PlanCard(
                                            plan: plan,
                                            isUpcoming: _isUpcomingPlan(plan),
                                            isAuthenticated:
                                                authState.isAuthenticated,
                                            isPremiumUser: hasPremiumAccess,
                                            hasBlockingPayment:
                                                hasPendingPayment ||
                                                hasCompletedPayment,
                                            isLoading:
                                                cryptoCheckoutState
                                                    .loadingPlanId ==
                                                plan.id,
                                            onPressed: () async {
                                              if (_isUpcomingPlan(plan)) {
                                                return;
                                              }

                                              if (plan.monthlyPrice == 0) {
                                                return;
                                              }

                                              if (!authState.isAuthenticated) {
                                                final registerUri = Uri(
                                                  path: '/register',
                                                  queryParameters: {
                                                    'redirectTo': '/plans',
                                                  },
                                                );
                                                context.go(
                                                  registerUri.toString(),
                                                );
                                                return;
                                              }

                                              await ref
                                                  .read(
                                                    cryptoCheckoutProvider
                                                        .notifier,
                                                  )
                                                  .createPayment(
                                                    planId: plan.id,
                                                  );
                                            },
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: plans
                                    .map(
                                      (plan) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                          ),
                                          child: _PlanCard(
                                            plan: plan,
                                            isUpcoming: _isUpcomingPlan(plan),
                                            isAuthenticated:
                                                authState.isAuthenticated,
                                            isPremiumUser: hasPremiumAccess,
                                            hasBlockingPayment:
                                                hasPendingPayment ||
                                                hasCompletedPayment,
                                            isLoading:
                                                cryptoCheckoutState
                                                    .loadingPlanId ==
                                                plan.id,
                                            onPressed: () async {
                                              if (_isUpcomingPlan(plan)) {
                                                return;
                                              }

                                              if (plan.monthlyPrice == 0) {
                                                return;
                                              }

                                              if (!authState.isAuthenticated) {
                                                final registerUri = Uri(
                                                  path: '/register',
                                                  queryParameters: {
                                                    'redirectTo': '/plans',
                                                  },
                                                );
                                                context.go(
                                                  registerUri.toString(),
                                                );
                                                return;
                                              }

                                              await ref
                                                  .read(
                                                    cryptoCheckoutProvider
                                                        .notifier,
                                                  )
                                                  .createPayment(
                                                    planId: plan.id,
                                                  );
                                            },
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              );
                            },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CryptoPaymentPanel extends StatelessWidget {
  const _CryptoPaymentPanel({
    required this.payment,
    required this.currencyText,
    required this.payAmountText,
    required this.isCancelling,
    required this.onCopy,
    required this.onRefresh,
    required this.onCancel,
  });

  final CryptoPaymentModel payment;
  final Widget currencyText;
  final String payAmountText;
  final bool isCancelling;
  final Future<void> Function(String label, String value) onCopy;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (payment.paymentStatus) {
      'finished' => const Color(0xFF21A45D),
      'failed' ||
      'expired' ||
      'refunded' ||
      'create_failed' => const Color(0xFFF05454),
      _ => const Color(0xFFFFB44C),
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF243247)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Active Crypto Payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  payment.paymentStatus.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            payment.isFinished
                ? 'Payment confirmed. Tap refresh if premium access has not appeared yet.'
                : 'Send the exact amount using USDT on BSC/BEP20 only. Do not send on ERC20 or TRC20.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _InfoTile(label: 'Pay Amount', value: payAmountText),
              _InfoTile(label: 'Currency', valueWidget: currencyText),
              _InfoTile(label: 'Order Id', value: payment.orderId),
            ],
          ),
          if (payment.payAddress != null &&
              payment.payAddress!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            const Text(
              'Wallet Address',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0B111C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF243247)),
              ),
              child: SelectableText(
                payment.payAddress!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (payment.payAddress != null && payment.payAddress!.isNotEmpty)
                FilledButton.icon(
                  onPressed: () =>
                      onCopy('Wallet address', payment.payAddress!),
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Copy Address'),
                ),
              if (payment.payAmount != null)
                OutlinedButton.icon(
                  onPressed: () => onCopy('Pay amount', payAmountText),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy Amount'),
                ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh Status'),
              ),
              if (onCancel != null)
                OutlinedButton.icon(
                  onPressed: isCancelling ? null : onCancel,
                  icon: isCancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close_rounded),
                  label: Text(isCancelling ? 'Cancelling...' : 'Cancel Order'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, this.value, this.valueWidget});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B111C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243247)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          valueWidget ??
              Text(
                value ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isUpcoming,
    required this.isAuthenticated,
    required this.isPremiumUser,
    required this.hasBlockingPayment,
    required this.isLoading,
    required this.onPressed,
  });

  final SubscriptionPlanModel plan;
  final bool isUpcoming;
  final bool isAuthenticated;
  final bool isPremiumUser;
  final bool hasBlockingPayment;
  final bool isLoading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (plan.tier) {
      SubscriptionTier.free => const Color(0xFF1F9DCC),
      SubscriptionTier.basic => const Color(0xFF21A45D),
      SubscriptionTier.premium => const Color(0xFFFFB44C),
      SubscriptionTier.platinum => const Color(0xFFF05454),
    };
    final bool isFreePlan = plan.monthlyPrice == 0;
    final bool isDisabled =
        isUpcoming ||
        isFreePlan ||
        isLoading ||
        (hasBlockingPayment && !isFreePlan) ||
        (isPremiumUser && !isFreePlan);
    final String priceLabel = isUpcoming
        ? 'Upcoming'
        : isFreePlan
        ? 'Free'
        : '${plan.monthlyPrice.toStringAsFixed(2)} USDT/month';
    final String buttonText = !isAuthenticated && !isUpcoming && !isFreePlan
        ? 'Create Account to Continue'
        : isUpcoming
        ? 'Upcoming'
        : isFreePlan
        ? 'Current Free Plan'
        : isPremiumUser
        ? 'Premium Active'
        : hasBlockingPayment
        ? 'Payment In Progress'
        : 'Choose Plan';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            plan.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            priceLabel,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (plan.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(plan.description),
          ],
          const SizedBox(height: 18),
          for (final String feature in plan.features) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.check_circle, color: accent, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(feature)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isDisabled ? null : () => onPressed(),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}
