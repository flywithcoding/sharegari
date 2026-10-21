/// Client-side model for the `public.pricing_config` singleton row.
class PricingConfig {
  const PricingConfig({
    required this.baseFareBdt,
    required this.perKmRateBdt,
    required this.perMinRateBdt,
    required this.minFareBdt,
    required this.sharingFactor,
    required this.platformFeePct,
    required this.smallGroupFareCap,
  });

  /// Fixed base charge added to every ride (৳).
  final double baseFareBdt;

  /// Rate charged per kilometre of route (৳/km).
  final double perKmRateBdt;

  /// Rate charged per minute of route duration (৳/min).
  final double perMinRateBdt;

  /// Minimum car fare regardless of distance (৳).
  final double minFareBdt;

  /// Multiplier applied before dividing by group size (default 0.70).
  /// Kept for matching-engine capping in Step 7.
  final double sharingFactor;

  /// Platform fee fraction (default 0.10 = 10%).
  final double platformFeePct;

  /// Cap: small-group price must not exceed this fraction of solo fare (0.60).
  final double smallGroupFareCap;

  factory PricingConfig.fromJson(Map<String, dynamic> json) {
    return PricingConfig(
      baseFareBdt: (json['base_fare_bdt'] as num).toDouble(),
      perKmRateBdt: (json['per_km_rate_bdt'] as num).toDouble(),
      perMinRateBdt: (json['per_min_rate_bdt'] as num? ?? 2.0).toDouble(),
      minFareBdt: (json['min_fare_bdt'] as num? ?? 50.0).toDouble(),
      sharingFactor: (json['sharing_factor'] as num).toDouble(),
      platformFeePct: (json['platform_fee_pct'] as num).toDouble(),
      smallGroupFareCap: (json['small_group_fare_cap'] as num).toDouble(),
    );
  }

  /// Hard-coded fallback used when the DB fetch fails (offline / first cold start).
  static const fallback = PricingConfig(
    baseFareBdt: 30.0,
    perKmRateBdt: 18.0,
    perMinRateBdt: 2.0,
    minFareBdt: 50.0,
    sharingFactor: 0.70,
    platformFeePct: 0.10,
    smallGroupFareCap: 0.60,
  );
}
