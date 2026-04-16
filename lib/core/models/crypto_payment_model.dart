import 'package:equatable/equatable.dart';

class CryptoPaymentModel extends Equatable {
  const CryptoPaymentModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.orderId,
    required this.paymentStatus,
    required this.priceAmount,
    required this.priceCurrency,
    this.provider = 'nowpayments',
    this.providerPaymentId,
    this.payCurrency,
    this.payAmount,
    this.payAddress,
    this.payinExtraId,
    this.orderDescription,
    this.purchaseId,
    this.outcomeAmount,
    this.outcomeCurrency,
    this.actuallyPaid,
    this.actuallyPaidAtFiat,
    this.parentPaymentId,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String planId;
  final String provider;
  final String orderId;
  final String? providerPaymentId;
  final String paymentStatus;
  final double priceAmount;
  final String priceCurrency;
  final String? payCurrency;
  final double? payAmount;
  final String? payAddress;
  final String? payinExtraId;
  final String? orderDescription;
  final String? purchaseId;
  final double? outcomeAmount;
  final String? outcomeCurrency;
  final double? actuallyPaid;
  final double? actuallyPaidAtFiat;
  final String? parentPaymentId;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFinished => paymentStatus == 'finished';

  bool get isPending => const {
    'creating',
    'new',
    'waiting',
    'confirming',
    'sending',
    'partially_paid',
  }.contains(paymentStatus);

  bool get isFailed => const {
    'failed',
    'expired',
    'refunded',
    'create_failed',
    'cancelled',
  }.contains(paymentStatus);

  factory CryptoPaymentModel.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return CryptoPaymentModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      planId: json['plan_id'].toString(),
      provider: (json['provider'] ?? 'nowpayments').toString(),
      orderId: json['order_id'].toString(),
      providerPaymentId: json['provider_payment_id']?.toString(),
      paymentStatus: (json['payment_status'] ?? 'creating')
          .toString()
          .toLowerCase(),
      priceAmount: toDouble(json['price_amount']) ?? 0,
      priceCurrency: (json['price_currency'] ?? 'usd').toString().toLowerCase(),
      payCurrency: json['pay_currency']?.toString().toLowerCase(),
      payAmount: toDouble(json['pay_amount']),
      payAddress: json['pay_address']?.toString(),
      payinExtraId: json['payin_extra_id']?.toString(),
      orderDescription: json['order_description']?.toString(),
      purchaseId: json['purchase_id']?.toString(),
      outcomeAmount: toDouble(json['outcome_amount']),
      outcomeCurrency: json['outcome_currency']?.toString().toLowerCase(),
      actuallyPaid: toDouble(json['actually_paid']),
      actuallyPaidAtFiat: toDouble(json['actually_paid_at_fiat']),
      parentPaymentId: json['parent_payment_id']?.toString(),
      paidAt: toDate(json['paid_at']),
      createdAt: toDate(json['created_at']),
      updatedAt: toDate(json['updated_at']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    planId,
    provider,
    orderId,
    providerPaymentId,
    paymentStatus,
    priceAmount,
    priceCurrency,
    payCurrency,
    payAmount,
    payAddress,
    payinExtraId,
    orderDescription,
    purchaseId,
    outcomeAmount,
    outcomeCurrency,
    actuallyPaid,
    actuallyPaidAtFiat,
    parentPaymentId,
    paidAt,
    createdAt,
    updatedAt,
  ];
}
