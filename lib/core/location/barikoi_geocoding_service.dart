import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sharegari/core/location/geocoding_service.dart';
import 'package:sharegari/core/location/location_model.dart';

/// Geocoding via Barikoi (Bangladesh-focused, free tier).
///
/// ## API key
/// Injected at compile time: `--dart-define-from-file=env.json` → `BARIKOI_API_KEY`.
/// Read via `String.fromEnvironment('BARIKOI_API_KEY')` (through [AppEnv]).
///
/// ## Endpoints (barikoi.xyz)
///   • Search  : GET https://barikoi.xyz/v2/api/search/autocomplete/place
///               `?api_key=<key>&q=<text>`
///   • Reverse : GET https://barikoi.xyz/v2/api/search/reverse/geocode/place
///               `?api_key=<key>&longitude=<lng>&latitude=<lat>`
///
/// Both endpoints are called **directly** from the device — no Supabase proxy.
/// On Android / iOS there are no CORS restrictions.
/// If you need Flutter Web support in future, add a Supabase Edge Function
/// (`supabase/functions/barikoi-search/index.ts` is already in the repo).
///
/// ## Real autocomplete response shape (2026-10-28)
/// ```json
/// {"places":[{"id":null,"longitude":"90.38","latitude":"23.86",
///             "address":"Uttara, Dhaka","uCode":"XUSWI61626"}]}
/// ```
class BarikoiGeocodingService implements GeocodingService {
  /// [apiKey] — compile-time BARIKOI_API_KEY via String.fromEnvironment.
  BarikoiGeocodingService(this._apiKey);

  final String _apiKey;

  static const _barikoiBase = 'barikoi.xyz';

  // ── Search ─────────────────────────────────────────────────────────────────

  @override
  Future<List<LocationResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.https(
      _barikoiBase,
      '/v2/api/search/autocomplete/place',
      {'api_key': _apiKey, 'q': query},
    );

    // Sanitized path shown in error messages — key is stripped from query params.
    final uriDisplay = '${uri.host}${uri.path}';

    late http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Barikoi] search network error ($uriDisplay): $e');
      throw GeocodingException('Network error contacting $uriDisplay: $e');
    }

    debugPrint('[Barikoi] search $uriDisplay → ${res.statusCode}: ${res.body}');

    if (res.statusCode != 200) {
      throw GeocodingException(
        'Search failed (HTTP ${res.statusCode}) — $uriDisplay',
        statusCode: res.statusCode,
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final places = (json['places'] as List?) ?? [];

    return places
        .map((p) => _placeToResult(p as Map<String, dynamic>))
        .whereType<LocationResult>()
        .toList();
  }

  // ── Reverse geocode ────────────────────────────────────────────────────────

  @override
  Future<LocationResult?> reverseGeocode(LatLng latLng) async {
    final uri = Uri.https(
      _barikoiBase,
      '/v2/api/search/reverse/geocode/place',
      {
        'api_key': _apiKey,
        'longitude': latLng.longitude.toStringAsFixed(6),
        'latitude': latLng.latitude.toStringAsFixed(6),
      },
    );

    final uriDisplay = '${uri.host}${uri.path}';

    late http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Barikoi] reverseGeocode network error ($uriDisplay): $e');
      return null; // non-fatal — pin stays unlabelled
    }

    debugPrint(
        '[Barikoi] reverseGeocode $uriDisplay → ${res.statusCode}: ${res.body}');

    if (res.statusCode != 200) {
      debugPrint(
          '[Barikoi] reverseGeocode failed — HTTP ${res.statusCode} ($uriDisplay)');
      return null;
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;

    // Reverse endpoint wraps the result in a "place" object (singular).
    final place = json['place'] as Map<String, dynamic>?;
    if (place == null) return null;

    return _placeToResult(place, fallbackLatLng: latLng);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Converts a raw Barikoi place map to [LocationResult].
  ///
  /// Real field names:
  ///   • "address"   — full formatted address string (always present)
  ///   • "latitude"  — string e.g. "23.86" → parsed with double.tryParse
  ///   • "longitude" — string e.g. "90.38" → parsed with double.tryParse
  ///   • "uCode"     — place identifier ("id" may be null — ignored)
  ///
  /// Optional (may be absent on autocomplete):
  ///   • "address_bn", "area", "city"
  LocationResult? _placeToResult(
    Map<String, dynamic> p, {
    LatLng? fallbackLatLng,
  }) {
    // Latitude and longitude come as strings in the Barikoi response.
    final lat = double.tryParse(p['latitude']?.toString() ?? '');
    final lng = double.tryParse(p['longitude']?.toString() ?? '');

    final LatLng latLng;
    if (lat != null && lng != null) {
      latLng = LatLng(lat, lng);
    } else if (fallbackLatLng != null) {
      latLng = fallbackLatLng;
    } else {
      debugPrint('[Barikoi] skipping place with missing coordinates: $p');
      return null;
    }

    // "address" is always present in real responses.
    final address = (p['address'] as String?)?.trim() ?? '';

    // Build a richer label when optional sub-fields exist.
    final parts = [
      p['address'] as String?,
      p['area'] as String?,
      p['city'] as String?,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final fullAddress = parts.isNotEmpty ? parts.join(', ') : address;

    // Prefer Bangla name when available.
    final name = (p['address_bn'] as String?)?.trim().isNotEmpty == true
        ? (p['address_bn'] as String).trim()
        : null;

    return LocationResult(
      latLng: latLng,
      name: name ?? (address.isNotEmpty ? address : null),
      address: fullAddress.isNotEmpty ? fullAddress : 'Unknown location',
    );
  }
}

/// Thrown by [BarikoiGeocodingService.search] on HTTP errors or network
/// failures so the UI can show a visible error instead of an empty list.
class GeocodingException implements Exception {
  const GeocodingException(this.message, {this.statusCode});

  final String message;

  /// HTTP status code when the error was a non-200 response.
  final int? statusCode;

  @override
  String toString() => statusCode != null
      ? 'GeocodingException: $message (HTTP $statusCode)'
      : 'GeocodingException: $message';
}
