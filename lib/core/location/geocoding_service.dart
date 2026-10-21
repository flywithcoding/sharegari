import 'package:sharegari/core/location/location_model.dart';

/// Abstract geocoding service interface.
///
/// Concrete implementations (Barikoi, Nominatim) are injected via Riverpod
/// so the UI never depends on a specific provider.
abstract class GeocodingService {
  /// Search for places matching [query].
  ///
  /// Returns an ordered list of [LocationResult] (best match first).
  /// Returns an empty list on no results; never throws.
  Future<List<LocationResult>> search(String query);

  /// Convert [latLng] coordinates to a human-readable address.
  ///
  /// Returns null when the reverse-geocode fails or returns no results.
  Future<LocationResult?> reverseGeocode(LatLng latLng);
}
