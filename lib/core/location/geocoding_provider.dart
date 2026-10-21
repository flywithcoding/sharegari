import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/core/env.dart';
import 'package:sharegari/core/location/barikoi_geocoding_service.dart';
import 'package:sharegari/core/location/geocoding_service.dart';
import 'package:sharegari/core/location/nominatim_geocoding_service.dart';

/// Provides the active [GeocodingService] implementation.
///
/// Uses Barikoi when a key is available, Nominatim otherwise.
/// Swap implementations here without touching any UI code.
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  if (AppEnv.barikoiApiKey.isNotEmpty) {
    return BarikoiGeocodingService(AppEnv.barikoiApiKey);
  }
  return NominatimGeocodingService();
});
