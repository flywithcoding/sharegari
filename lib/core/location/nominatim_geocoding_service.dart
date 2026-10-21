import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sharegari/core/location/geocoding_service.dart';
import 'package:sharegari/core/location/location_model.dart';

/// Geocoding fallback via Nominatim (OpenStreetMap).
///
/// Used when Barikoi returns no results or fails.
/// Rate limit: max 1 request/second — only call on explicit user search,
/// not on every keystroke.
class NominatimGeocodingService implements GeocodingService {
  static const _base = 'nominatim.openstreetmap.org';

  static const _headers = {
    // Required by Nominatim usage policy
    'User-Agent': 'ShareGari/1.0 (sharegari@example.com)',
    'Accept-Language': 'en,bn',
  };

  @override
  Future<List<LocationResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.https(_base, '/search', {
        'q': query,
        'format': 'jsonv2',
        'countrycodes': 'bd',
        'limit': '6',
        'addressdetails': '1',
      });
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List;
      return list.map((item) {
        final lat = double.tryParse(item['lat'].toString()) ?? 0.0;
        final lng = double.tryParse(item['lon'].toString()) ?? 0.0;
        return LocationResult(
          latLng: LatLng(lat, lng),
          name: item['name'] as String?,
          address: item['display_name'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<LocationResult?> reverseGeocode(LatLng latLng) async {
    try {
      final uri = Uri.https(_base, '/reverse', {
        'lat': latLng.latitude.toString(),
        'lon': latLng.longitude.toString(),
        'format': 'jsonv2',
      });
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json.containsKey('error')) return null;
      return LocationResult(
        latLng: latLng,
        name: json['name'] as String?,
        address: json['display_name'] as String? ?? 'Unknown location',
      );
    } catch (_) {
      return null;
    }
  }
}
