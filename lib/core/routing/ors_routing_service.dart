import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sharegari/core/env.dart';
import 'package:sharegari/core/location/location_model.dart';
import 'package:sharegari/core/routing/routing_service.dart';

/// OpenRouteService driving-route implementation.
///
/// Docs: https://openrouteservice.org/dev/#/api-docs/v2/directions/{profile}/json/post
/// Profile: `driving-car`
/// Free tier: 2,000 requests/day, 40/minute.
///
/// All calls are wrapped in try-catch; returns null on any error so the UI
/// degrades gracefully (shows "Route unavailable" instead of crashing).
class OrsRoutingService implements RoutingService {
  OrsRoutingService(this._apiKey);

  final String _apiKey;

  static const _base = 'https://api.openrouteservice.org/v2/directions/driving-car/json';
  static const _timeout = Duration(seconds: 10);

  @override
  Future<OrsRouteResult?> getRoute(LatLng from, LatLng to) =>
      getRouteMulti([from, to]);

  @override
  Future<OrsRouteResult?> getRouteMulti(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;
    if (_apiKey.isEmpty) return null;

    // ORS coordinate format: [[lng, lat], ...]
    final coords = waypoints
        .map((p) => [p.longitude, p.latitude])
        .toList();

    try {
      final response = await http
          .post(
            Uri.parse(_base),
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json',
              'Accept': 'application/json, application/geo+json',
            },
            body: jsonEncode({'coordinates': coords}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final summary = (routes.first as Map<String, dynamic>)['summary']
          as Map<String, dynamic>;

      return OrsRouteResult(
        distanceM: (summary['distance'] as num).toDouble(),
        durationS: (summary['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider for [RoutingService].
///
/// Returns [OrsRoutingService] when ORS_API_KEY is present.
/// Returns [_NoopRoutingService] (always null) otherwise — the UI shows
/// "Route unavailable" without crashing.
final routingServiceProvider = Provider<RoutingService>((ref) {
  final key = AppEnv.orsApiKey;
  if (key.isNotEmpty) return OrsRoutingService(key);
  return _NoopRoutingService();
});

/// Fallback when no ORS key is configured.
class _NoopRoutingService implements RoutingService {
  @override
  Future<OrsRouteResult?> getRoute(LatLng from, LatLng to) async => null;

  @override
  Future<OrsRouteResult?> getRouteMulti(List<LatLng> waypoints) async => null;
}
