/// Pure fare calculator — no Flutter, no HTTP, no Supabase.
///
/// All rules come from the PRD §7.3 and the [PricingConfig] DB row.
/// This class has zero external dependencies so it is trivially unit-testable.
///
/// ## Formula
/// ```
/// car_fare  = max(min_fare, base_fare + per_km × route_km + per_min × route_min)
/// rider_fare(n) = roundUp5(car_fare / n)
/// ```
/// where n is the group size (2, 3, or 4).
///
/// ## Pre-match estimate shown to rider
/// Before a group is formed we don't know the group size, so we show a range:
///   • worst case  → n = 2 (2-person group, highest per-person share)
///   • best case   → n = 4 (4-person group, cheapest per-person)
class FareCalculator {
  const FareCalculator(this.config);

  final ({
    double baseFareBdt,
    double perKmRateBdt,
    double perMinRateBdt,
    double minFareBdt,
    double platformFeePct,
    double smallGroupFareCap,
  }) config;

  // ── Core formula ─────────────────────────────────────────────────────

  /// Computes the total car fare for the given route.
  ///
  /// [distanceKm] — route length in kilometres.
  /// [durationMin] — route duration in minutes.
  double carFare({required double distanceKm, required double durationMin}) {
    final raw = config.baseFareBdt +
        config.perKmRateBdt * distanceKm +
        config.perMinRateBdt * durationMin;
    return raw < config.minFareBdt ? config.minFareBdt : raw;
  }

  /// Per-rider fare (including platform fee) for a given group size.
  ///
  /// Result is rounded **up** to the nearest 5 taka.
  double riderFare({
    required double distanceKm,
    required double durationMin,
    required int groupSize,
  }) {
    assert(groupSize >= 1 && groupSize <= 4);
    final car = carFare(distanceKm: distanceKm, durationMin: durationMin);
    final split = car / groupSize;
    final withFee = split * (1 + config.platformFeePct);
    return _roundUp5(withFee);
  }

  /// Returns the [FareRange] shown before matching.
  ///
  /// Uses the rider's own trip distance/duration as the route proxy.
  /// [loGroupSize] = 4 (cheapest), [hiGroupSize] = 2 (most expensive).
  FareRange estimateRange({
    required double distanceKm,
    required double durationMin,
  }) {
    return FareRange(
      low: riderFare(
          distanceKm: distanceKm, durationMin: durationMin, groupSize: 4),
      high: riderFare(
          distanceKm: distanceKm, durationMin: durationMin, groupSize: 2),
    );
  }

  /// Solo (non-shared) car fare — used for the small-group price cap check.
  double soloFare({required double distanceKm, required double durationMin}) {
    return carFare(distanceKm: distanceKm, durationMin: durationMin) *
        (1 + config.platformFeePct);
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Rounds [value] up to the nearest multiple of 5.
  static double _roundUp5(double value) {
    final int taka = value.ceil();
    final int rem = taka % 5;
    return (rem == 0 ? taka : taka + (5 - rem)).toDouble();
  }
}

/// A pre-match fare estimate shown to the rider as a range.
class FareRange {
  const FareRange({required this.low, required this.high});

  /// Best-case per-rider fare (group of 4).
  final double low;

  /// Worst-case per-rider fare (group of 2).
  final double high;

  /// Human-readable label, e.g. "৳125 – ৳250".
  String get label => '৳${low.toStringAsFixed(0)} – ৳${high.toStringAsFixed(0)}';

  @override
  String toString() => 'FareRange($label)';
}
