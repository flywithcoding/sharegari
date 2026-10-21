import 'package:latlong2/latlong.dart';

export 'package:latlong2/latlong.dart' show LatLng;

/// A geocoding result: a coordinate pair with a human-readable label.
class LocationResult {
  const LocationResult({
    required this.latLng,
    required this.address,
    this.name,
  });

  /// Geographic coordinate.
  final LatLng latLng;

  /// Full formatted address string.
  final String address;

  /// Short place name (e.g. "Gulshan-1" or "Dhaka University").
  /// Null when only a raw reverse-geocode result is available.
  final String? name;

  /// Best display label: name if available, otherwise address.
  String get displayLabel => name ?? address;

  @override
  String toString() => 'LocationResult($latLng, "$displayLabel")';
}
