import 'package:flutter_test/flutter_test.dart';
import 'package:sharegari/core/pricing/fare_calculator.dart';

/// Unit tests for [FareCalculator].
///
/// These tests are pure Dart — no Flutter, no Supabase, no HTTP.
/// Run with:  flutter test test/fare_calculator_test.dart
void main() {
  // ── Shared test config ────────────────────────────────────────────────
  const config = (
    baseFareBdt: 30.0,
    perKmRateBdt: 18.0,
    perMinRateBdt: 2.0,
    minFareBdt: 50.0,
    platformFeePct: 0.10,
    smallGroupFareCap: 0.60,
  );

  late FareCalculator calc;

  setUp(() => calc = FareCalculator(config));

  // ── carFare ───────────────────────────────────────────────────────────
  group('carFare', () {
    test('typical 10 km / 20 min trip', () {
      // 30 + 18×10 + 2×20 = 30 + 180 + 40 = 250
      expect(calc.carFare(distanceKm: 10, durationMin: 20), 250.0);
    });

    test('very short trip is clamped to minFare', () {
      // 30 + 18×0.5 + 2×2 = 30 + 9 + 4 = 43 < 50 → 50
      expect(calc.carFare(distanceKm: 0.5, durationMin: 2), 50.0);
    });

    test('zero distance still respects minFare', () {
      expect(calc.carFare(distanceKm: 0, durationMin: 0), 50.0);
    });

    test('long 30 km / 60 min trip', () {
      // 30 + 18×30 + 2×60 = 30 + 540 + 120 = 690
      expect(calc.carFare(distanceKm: 30, durationMin: 60), 690.0);
    });
  });

  // ── riderFare ─────────────────────────────────────────────────────────
  group('riderFare', () {
    // car = 250, split4 = 62.5, +10% = 68.75 → roundUp5 = 70
    test('group of 4 — 10 km / 20 min', () {
      expect(
          calc.riderFare(distanceKm: 10, durationMin: 20, groupSize: 4), 70.0);
    });

    // car = 250, split2 = 125, +10% = 137.5 → roundUp5 = 140
    test('group of 2 — 10 km / 20 min', () {
      expect(
          calc.riderFare(distanceKm: 10, durationMin: 20, groupSize: 2), 140.0);
    });

    // car = 250, split3 ≈ 83.33, +10% ≈ 91.67 → roundUp5 = 95
    test('group of 3 — 10 km / 20 min', () {
      expect(
          calc.riderFare(distanceKm: 10, durationMin: 20, groupSize: 3), 95.0);
    });

    test('group of 1 (solo) includes platform fee', () {
      // car = 250, split1 = 250, +10% = 275 → roundUp5 = 275
      expect(
          calc.riderFare(distanceKm: 10, durationMin: 20, groupSize: 1), 275.0);
    });

    test('result is always a multiple of 5', () {
      for (final km in [1.0, 3.7, 8.2, 15.5, 22.0]) {
        for (final min in [5.0, 12.0, 35.0]) {
          for (final n in [2, 3, 4]) {
            final fare =
                calc.riderFare(distanceKm: km, durationMin: min, groupSize: n);
            expect(fare % 5, 0,
                reason:
                    'fare ৳$fare not multiple of 5 for ${km}km/${min}min/n=$n');
          }
        }
      }
    });

    test('minFare path: very short trip group of 2', () {
      // car = max(50, 30+9+4) = 50; split2 = 25; +10% = 27.5 → 30
      expect(
          calc.riderFare(distanceKm: 0.5, durationMin: 2, groupSize: 2), 30.0);
    });
  });

  // ── estimateRange ─────────────────────────────────────────────────────
  group('estimateRange', () {
    test('low (n=4) < high (n=2)', () {
      final range = calc.estimateRange(distanceKm: 10, durationMin: 20);
      expect(range.low, lessThan(range.high));
    });

    test('low == riderFare(n=4) and high == riderFare(n=2)', () {
      final range = calc.estimateRange(distanceKm: 10, durationMin: 20);
      expect(range.low,
          calc.riderFare(distanceKm: 10, durationMin: 20, groupSize: 4));
      expect(range.high,
          calc.riderFare(distanceKm: 10, durationMin: 20, groupSize: 2));
    });

    test('label format contains ৳ symbol and –', () {
      final label =
          calc.estimateRange(distanceKm: 10, durationMin: 20).label;
      expect(label, contains('৳'));
      expect(label, contains('–'));
    });
  });

  // ── roundUp5 edge cases ───────────────────────────────────────────────
  group('rounding', () {
    test('exact multiple of 5 is unchanged', () {
      // 250 / 4 = 62.5, +10% = 68.75 → 70 (not 65, not 75)
      final fare =
          calc.riderFare(distanceKm: 10, durationMin: 20, groupSize: 4);
      expect(fare, 70.0);
    });

    test('already on 5-boundary stays the same', () {
      // car = 30 + 18×5 + 2×10 = 30+90+20 = 140
      // split4 = 35, +10% = 38.5 → roundUp5 = 40
      final fare =
          calc.riderFare(distanceKm: 5, durationMin: 10, groupSize: 4);
      expect(fare, 40.0);
      expect(fare % 5, 0);
    });
  });
}
