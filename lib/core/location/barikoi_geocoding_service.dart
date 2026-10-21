import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sharegari/core/location/geocoding_service.dart';
import 'package:sharegari/core/location/location_model.dart';

/// Geocoding via Barikoi (Bangladesh-focused, free tier).
///
/// Docs: https://docs.barikoi.com
/// Endpoints used:
///   • Search  : GET https://barikoi.com/v2/api/search/autocomplete/...
///   • Reverse : GET https://barikoi.com/v2/api/search/reverse/geocode/...
class BarikoiGeocodingService implements GeocodingService {
  BarikoiGeocodingService(this._apiKey);

  final String _apiKey;

  static const _base = 'barikoi.com';

  @override
  Future<List<LocationResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.https(_base, '/v2/api/search/autocomplete/$_apiKey/json',
          {'q': query, 'country': 'bangladesh', 'limit': '8'});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final places = (json['places'] as List?) ?? [];
      return places.map((p) {
        final lat = double.tryParse(p['latitude'].toString()) ?? 0.0;
        final lng = double.tryParse(p['longitude'].toString()) ?? 0.0;
        return LocationResult(
          latLng: LatLng(lat, lng),
          name: p['address_bn'] as String? ?? p['address'] as String? ?? '',
          address: [
            p['address'],
            p['area'],
            p['city'],
          ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<LocationResult?> reverseGeocode(LatLng latLng) async {
    try {
      final uri = Uri.https(
          _base, '/v2/api/search/reverse/geocode/$_apiKey/json', {
        'longitude': latLng.longitude.toString(),
        'latitude': latLng.latitude.toString(),
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final place = json['place'] as Map<String, dynamic>?;
      if (place == null) return null;
      final address = [
        place['address'],
        place['area'],
        place['city'],
      ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
      return LocationResult(
        latLng: latLng,
        name: place['address_bn'] as String? ?? place['address'] as String?,
        address: address.isNotEmpty ? address : 'Unknown location',
      );
    } catch (_) {
      return null;
    }
  }
}
