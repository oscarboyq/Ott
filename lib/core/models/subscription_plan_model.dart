import 'package:equatable/equatable.dart';

enum SubscriptionTier { free, basic, premium, platinum }

class SubscriptionPlanModel extends Equatable {
  final String id;
  final SubscriptionTier tier;
  final String name;
  final String description;
  final double monthlyPrice;
  final double yearlyPrice;
  final int maxDevices;
  final bool hd;
  final bool fourK;
  final bool adFree;
  final bool offlineDownload;
  final List<String> features;
  final bool isActive;

  const SubscriptionPlanModel({
    required this.id,
    required this.tier,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.maxDevices,
    required this.hd,
    required this.fourK,
    required this.adFree,
    required this.offlineDownload,
    required this.features,
    required this.isActive,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    // Supabase stores features as JSONB: {"key_features": ["feature1", ...]}
    // Support both Supabase format and legacy list format
    final featuresRaw = json['features'];
    final List<String> featuresList;
    if (featuresRaw is Map) {
      featuresList = List<String>.from(
        (featuresRaw['key_features'] as List? ?? []),
      );
    } else if (featuresRaw is List) {
      featuresList = List<String>.from(featuresRaw);
    } else {
      featuresList = [];
    }

    return SubscriptionPlanModel(
      id: json['id'] as String,
      // DB does not have a 'tier' column — derive from name
      tier: _tierFromName(json['name'] as String? ?? ''),
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      // Supabase: 'monthly_price', legacy: 'monthlyPrice'
      monthlyPrice:
          ((json['monthly_price'] ?? json['monthlyPrice']) as num?)
              ?.toDouble() ??
          0.0,
      // Supabase: 'annual_price', legacy: 'yearlyPrice'
      yearlyPrice:
          ((json['annual_price'] ?? json['yearlyPrice']) as num?)?.toDouble() ??
          0.0,
      maxDevices: json['maxDevices'] as int? ?? 1,
      hd: json['hd'] as bool? ?? false,
      fourK: json['fourK'] as bool? ?? false,
      adFree: json['adFree'] as bool? ?? false,
      offlineDownload: json['offlineDownload'] as bool? ?? false,
      features: featuresList,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static SubscriptionTier _tierFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('vip')) {
      return SubscriptionTier.platinum;
    } else if (lower.contains('premium')) {
      return SubscriptionTier.premium;
    } else if (lower.contains('basic')) {
      return SubscriptionTier.basic;
    } else if (lower.contains('platinum')) {
      return SubscriptionTier.platinum;
    }
    return SubscriptionTier.free;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tier': tier.name,
      'name': name,
      'description': description,
      'monthlyPrice': monthlyPrice,
      'yearlyPrice': yearlyPrice,
      'maxDevices': maxDevices,
      'hd': hd,
      'fourK': fourK,
      'adFree': adFree,
      'offlineDownload': offlineDownload,
      'features': features,
      'isActive': isActive,
    };
  }

  SubscriptionPlanModel copyWith({
    String? id,
    SubscriptionTier? tier,
    String? name,
    String? description,
    double? monthlyPrice,
    double? yearlyPrice,
    int? maxDevices,
    bool? hd,
    bool? fourK,
    bool? adFree,
    bool? offlineDownload,
    List<String>? features,
    bool? isActive,
  }) {
    return SubscriptionPlanModel(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      name: name ?? this.name,
      description: description ?? this.description,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      yearlyPrice: yearlyPrice ?? this.yearlyPrice,
      maxDevices: maxDevices ?? this.maxDevices,
      hd: hd ?? this.hd,
      fourK: fourK ?? this.fourK,
      adFree: adFree ?? this.adFree,
      offlineDownload: offlineDownload ?? this.offlineDownload,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tier,
    name,
    description,
    monthlyPrice,
    yearlyPrice,
    maxDevices,
    hd,
    fourK,
    adFree,
    offlineDownload,
    features,
    isActive,
  ];
}
