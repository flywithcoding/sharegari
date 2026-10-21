import 'package:sharegari/core/location/location_model.dart';

/// Mirrors the `request_status` Postgres enum.
enum RideRequestStatus {
  pending,
  matched,
  confirmed,
  inProgress,
  completed,
  cancelled,
  expired;

  static RideRequestStatus fromString(String v) => switch (v) {
        'pending' => pending,
        'matched' => matched,
        'confirmed' => confirmed,
        'in_progress' => inProgress,
        'completed' => completed,
        'cancelled' => cancelled,
        'expired' => expired,
        _ => pending,
      };

  String get label => switch (this) {
        pending => 'Finding riders',
        matched => 'Matched',
        confirmed => 'Confirmed',
        inProgress => 'In progress',
        completed => 'Completed',
        cancelled => 'Cancelled',
        expired => 'Expired',
      };

  bool get isActive =>
      this == pending || this == matched || this == confirmed ||
      this == inProgress;
}

/// Client-side model for a `public.ride_requests` row.
class RideRequest {
  const RideRequest({
    required this.id,
    required this.riderId,
    required this.pickupLatLng,
    required this.pickupAddress,
    required this.dropLatLng,
    required this.dropAddress,
    required this.departAt,
    required this.windowMin,
    required this.status,
    this.estimatedSoloFare,
    this.estimatedShareFare,
    required this.createdAt,
  });

  final String id;
  final String riderId;
  final LatLng pickupLatLng;
  final String pickupAddress;
  final LatLng dropLatLng;
  final String dropAddress;
  final DateTime departAt;
  final int windowMin;
  final RideRequestStatus status;
  final double? estimatedSoloFare;
  final double? estimatedShareFare;
  final DateTime createdAt;

  /// Deserialise from a Supabase row map.
  ///
  /// PostGIS `geography(Point)` columns are returned by Supabase as WKT strings:
  /// `POINT(longitude latitude)` — note longitude comes first.
  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['id'] as String,
      riderId: json['rider_id'] as String,
      pickupLatLng: _parseGeo(json['pickup_geo'] as String),
      pickupAddress: json['pickup_address'] as String,
      dropLatLng: _parseGeo(json['drop_geo'] as String),
      dropAddress: json['drop_address'] as String,
      departAt: DateTime.parse(json['depart_at'] as String).toLocal(),
      windowMin: json['window_min'] as int,
      status:
          RideRequestStatus.fromString(json['status'] as String? ?? 'pending'),
      estimatedSoloFare: (json['estimated_solo_fare'] as num?)?.toDouble(),
      estimatedShareFare: (json['estimated_share_fare'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  /// Serialise for INSERT.
  ///
  /// `pickup_geo` and `drop_geo` are sent as WKT so PostGIS parses them:
  /// `SRID=4326;POINT(longitude latitude)`.
  Map<String, dynamic> toInsertJson() {
    return {
      'rider_id': riderId,
      'pickup_geo': _toWkt(pickupLatLng),
      'pickup_address': pickupAddress,
      'drop_geo': _toWkt(dropLatLng),
      'drop_address': dropAddress,
      'depart_at': departAt.toUtc().toIso8601String(),
      'window_min': windowMin,
      // Fare estimates will be filled in Step 6 once ORS distance is known.
    };
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Parses `POINT(lng lat)` WKT (PostGIS default output format).
  static LatLng _parseGeo(String wkt) {
    // e.g. "POINT(90.4125 23.8103)"
    final inner = wkt
        .replaceAll('POINT(', '')
        .replaceAll('POINT (', '')
        .replaceAll(')', '')
        .trim();
    final parts = inner.split(' ');
    final lng = double.parse(parts[0]);
    final lat = double.parse(parts[1]);
    return LatLng(lat, lng);
  }

  /// Converts LatLng to EWKT (longitude first — PostGIS convention).
  static String _toWkt(LatLng p) =>
      'SRID=4326;POINT(${p.longitude} ${p.latitude})';
}
