import 'package:flutter/material.dart';

/// Central motion tokens for ShareGari.
/// Ensures consistent animations across the app and respects reduced motion.
abstract final class AppMotion {
  // ── Durations ─────────────────────────────────────────────────────────────
  /// Fast: 150 ms — micro-interactions, press feedback, toggles, chips.
  static const Duration fast = Duration(milliseconds: 150);

  /// Normal: 250 ms — page transitions, sheet expansions, card fades.
  static const Duration normal = Duration(milliseconds: 250);

  /// Slow: 400 ms — entrance choreography, success reveals, modal transitions.
  static const Duration slow = Duration(milliseconds: 400);

  // ── Curves ────────────────────────────────────────────────────────────────
  /// Curve for entrances and reveals: [Curves.easeOutCubic].
  static const Curve entranceCurve = Curves.easeOutCubic;

  /// Curve for state switches and transitions: [Curves.easeInOut].
  static const Curve stateChangeCurve = Curves.easeInOut;

  // ── Helpers ───────────────────────────────────────────────────────────────
  /// Returns whether the user has requested reduced motion.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Returns [Duration.zero] if animations are disabled, or [d] otherwise.
  static Duration duration(BuildContext context, Duration d) {
    return isReducedMotion(context) ? Duration.zero : d;
  }
}

