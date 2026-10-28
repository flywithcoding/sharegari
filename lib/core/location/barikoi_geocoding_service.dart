import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sharegari/core/location/geocoding_service.dart';
import 'package:sharegari/core/location/location_model.dart';

/// Geocoding via Barikoi (Bangladesh-focused, free tier).
///
/// API key is injected at compile time via:
///   --dart-define-from-file=env.json  →  BARIKOI_API_KEY
///
/// Docs: https://docs.barikoi.com
/// Endpoints used:
///   • Search  : GET https://barikoi.com/v2/api/search/autocomplete/{key}/json?q=...
///   • Reverse : GET https://barikoi.com/v2/api/search/reverse/geocode/{key}/json?longitude=...&latitude=...
///
/// Real autocomplete response shape (2026-10-28):
/// ```json
/// {"places":[{"id":null,"longitude":"90.38","latitude":"23.86",
///             "address":"Uttara, Dhaka","uCode":"XUSWI61626"}]}
/// ```
/// Real reverse-geocode response shape:
/// ```json
/// {"status":200,"place":{"id":123,"longitude":"90.38","latitude":"23.86",
///                         "address":"Uttara, Dhaka","area":"Uttara",...}}
/// ```
class BarikoiGeocodingService implements GeocodingService {
  BarikoiGeocodingService(this._apiKey);

  final String _apiKey;

  static const _base = 'barikoi.com';

  // ── Search ─────────────────────────────────────────────────────────────────

  @override
  Future<List<LocationResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.https(
      _base,
      '/v2/api/search/autocomplete/$_apiKey/json',
      {'q': query, 'country': 'bangladesh', 'limit': '8'},
    );

    late http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Barikoi] search network error: $e');
      throw GeocodingException('Network error: $e');
    }

    debugPrint('[Barikoi] search raw response (${res.statusCode}): ${res.body}');

    if (res.statusCode != 200) {
      throw GeocodingException(
        'Search failed — HTTP ${res.statusCode}',
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
      _base,
      '/v2/api/search/reverse/geocode/$_apiKey/json',
      {
        'longitude': latLng.longitude.toStringAsFixed(6),
        'latitude': latLng.latitude.toStringAsFixed(6),
      },
    );

    late http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Barikoi] reverseGeocode network error: $e');
      return null; // reverse geocode errors are non-fatal (pin just stays unlabelled)
    }

    debugPrint(
        '[Barikoi] reverseGeocode raw response (${res.statusCode}): ${res.body}');

    if (res.statusCode != 200) {
      debugPrint('[Barikoi] reverseGeocode failed — HTTP ${res.statusCode}');
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
  /// The real API response has:
  ///   • "address"   — full formatted address string (always present)
  ///   • "latitude"  — string (e.g. "23.86")
  ///   • "longitude" — string (e.g. "90.38")
  ///   • "uCode"     — place identifier (not "id" — that may be null)
  ///
  /// Optional richer fields (may be absent on autocomplete):
  ///   • "address_bn" — Bangla address
  ///   • "area", "city", "subarea"
  LocationResult? _placeToResult(
    Map<String, dynamic> p, {
    LatLng? fallbackLatLng,
  }) {
    // Coordinates — stored as strings in the Barikoi response.
    final lat = double.tryParse(p['latitude']?.toString() ?? '');
    final lng = double.tryParse(p['longitude']?.toString() ?? '');

    // If lat/lng are missing, use the fallback (provided for reverse-geocode).
    final LatLng latLng;
    if (lat != null && lng != null) {
      latLng = LatLng(lat, lng);
    } else if (fallbackLatLng != null) {
      latLng = fallbackLatLng;
    } else {
      debugPrint('[Barikoi] skipping place with missing coordinates: $p');
      return null;
    }

    // Primary display label — "address" is always present in real responses.
    // Fall back through progressively simpler labels.
    final address = (p['address'] as String?)?.trim() ?? '';

    // Build a richer full-address string if optional sub-fields exist.
    final parts = [
      p['address'] as String?,
      p['area'] as String?,
      p['city'] as String?,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final fullAddress = parts.isNotEmpty ? parts.join(', ') : address;

    // Prefer Bangla name when available, otherwise use the English address.
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

/// Thrown by [BarikoiGeocodingService.search] when the HTTP request fails.
///
/// The UI catches this to show a visible error message with the status code
/// instead of silently returning an empty list.
class GeocodingException implements Exception {
  const GeocodingException(this.message, {this.statusCode});

  final String message;

  /// HTTP status code, if the error was a non-200 response.
  final int? statusCode;

  @override
  String toString() => statusCode != null
      ? 'GeocodingException: $message (HTTP $statusCode)'
      : 'GeocodingException: $message';
}
