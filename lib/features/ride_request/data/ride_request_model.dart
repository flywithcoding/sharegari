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
///
/// ## Geography columns
/// PostgREST / Supabase returns `geography(Point)` columns as raw hex EWKB
/// (e.g. `0101000020E6100000...`), which Dart cannot parse as coordinates.
///
/// Migration `004_geo_latlong_columns.sql` adds four GENERATED ALWAYS AS
/// computed columns: `pickup_lat`, `pickup_lng`, `drop_lat`, `drop_lng`.
/// All reads use these plain `double` fields; all writes still use the
/// `pickup_geo` / `drop_geo` geography columns via EWKT.
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
  /// Reads `pickup_lat` / `pickup_lng` / `drop_lat` / `drop_lng` —
  /// generated columns that contain plain `double` values.
  /// The hex EWKB geography columns (`pickup_geo`, `drop_geo`) are never
  /// fetched (the SELECT list in [RideRequestRepository] excludes them).
  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['id'] as String,
      riderId: json['rider_id'] as String,
      pickupLatLng: LatLng(
        (json['pickup_lat'] as num).toDouble(),
        (json['pickup_lng'] as num).toDouble(),
      ),
      pickupAddress: json['pickup_address'] as String,
      dropLatLng: LatLng(
        (json['drop_lat'] as num).toDouble(),
        (json['drop_lng'] as num).toDouble(),
      ),
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
  /// Writes to the `geography` columns using EWKT so PostGIS parses them
  /// server-side: `SRID=4326;POINT(longitude latitude)`.
  /// The generated lat/lng columns update automatically.
  Map<String, dynamic> toInsertJson() {
    return {
      'rider_id': riderId,
      'pickup_geo': _toWkt(pickupLatLng),
      'pickup_address': pickupAddress,
      'drop_geo': _toWkt(dropLatLng),
      'drop_address': dropAddress,
      'depart_at': departAt.toUtc().toIso8601String(),
      'window_min': windowMin,
      if (estimatedSoloFare != null)
        'estimated_solo_fare': estimatedSoloFare,
      if (estimatedShareFare != null)
        'estimated_share_fare': estimatedShareFare,
    };
  }

  // ── Helper ───────────────────────────────────────────────────────────

  /// Converts LatLng to EWKT (longitude first — PostGIS convention).
  static String _toWkt(LatLng p) =>
      'SRID=4326;POINT(${p.longitude} ${p.latitude})';
}
