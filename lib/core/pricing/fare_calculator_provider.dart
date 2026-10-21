import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/core/pricing/fare_calculator.dart';
import 'package:sharegari/core/pricing/pricing_config.dart';
import 'package:sharegari/core/pricing/pricing_config_repository.dart';

/// Riverpod provider that wires [PricingConfig] into [FareCalculator].
///
/// Uses [pricingConfigSyncProvider] so callers get an immediately usable
/// instance (backed by the fallback until the DB fetch completes).
final fareCalculatorProvider = Provider<FareCalculator>((ref) {
  final cfg = ref.watch(pricingConfigSyncProvider);
  return FareCalculator((
    baseFareBdt: cfg.baseFareBdt,
    perKmRateBdt: cfg.perKmRateBdt,
    perMinRateBdt: cfg.perMinRateBdt,
    minFareBdt: cfg.minFareBdt,
    platformFeePct: cfg.platformFeePct,
    smallGroupFareCap: cfg.smallGroupFareCap,
  ));
});
