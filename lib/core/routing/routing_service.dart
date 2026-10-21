import 'package:sharegari/core/location/location_model.dart';

/// Result from a routing service call.
class OrsRouteResult {
  const OrsRouteResult({
    required this.distanceM,
    required this.durationS,
  });

  /// Route length in metres.
  final double distanceM;

  /// Route duration in seconds.
  final double durationS;

  /// Route length in kilometres.
  double get distanceKm => distanceM / 1000.0;

  /// Route duration in minutes.
  double get durationMin => durationS / 60.0;

  @override
  String toString() =>
      'OrsRouteResult(${distanceKm.toStringAsFixed(2)} km, '
      '${durationMin.toStringAsFixed(1)} min)';
}

/// Abstract routing service interface.
///
/// Wrapping ORS (or any future provider) behind this interface keeps
/// [FareCalculator] and UI code provider-agnostic.
abstract class RoutingService {
  /// Returns the driving route between [from] and [to].
  ///
  /// Returns null when the service is unreachable or no route is found.
  Future<OrsRouteResult?> getRoute(LatLng from, LatLng to);

  /// Returns the driving route through an ordered list of [waypoints].
  ///
  /// Used by the matching engine (Step 7) to compute the full shared route.
  /// Returns null on failure.
  Future<OrsRouteResult?> getRouteMulti(List<LatLng> waypoints);
}
