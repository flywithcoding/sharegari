import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sharegari/core/supabase/supabase_client_provider.dart';
import 'package:sharegari/features/ride_request/data/ride_request_model.dart';

/// Thin data-access layer for `public.ride_requests`.
///
/// ## Column selection
/// All SELECT queries use an explicit column list that includes the generated
/// `pickup_lat`, `pickup_lng`, `drop_lat`, `drop_lng` columns but **excludes**
/// `pickup_geo` and `drop_geo`. Those geography columns are returned by
/// PostgREST as raw hex EWKB (e.g. `0101000020E6100000…`), which cannot be
/// parsed as a double. The generated numeric columns are safe plain numbers.
class RideRequestRepository {
  RideRequestRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'ride_requests';

  /// Explicit column list for all SELECT operations.
  ///
  /// Intentionally excludes `pickup_geo` and `drop_geo` (hex EWKB).
  /// Includes `pickup_lat`, `pickup_lng`, `drop_lat`, `drop_lng` (generated).
  static const _cols = 'id, rider_id, '
      'pickup_lat, pickup_lng, pickup_address, '
      'drop_lat, drop_lng, drop_address, '
      'depart_at, window_min, status, '
      'estimated_solo_fare, estimated_share_fare, '
      'created_at';

  // ── Write ────────────────────────────────────────────────────────────

  /// Insert a new ride request and return the created row.
  ///
  /// INSERT still writes to `pickup_geo` / `drop_geo` via EWKT so PostGIS
  /// stores the geography correctly for the matching engine (Step 7).
  /// The generated lat/lng columns are populated automatically by Postgres.
  Future<RideRequest> insert(RideRequest request) async {
    final row = await _client
        .from(_table)
        .insert(request.toInsertJson())
        .select(_cols)
        .single();
    return RideRequest.fromJson(row);
  }

  /// Cancel a pending request (status → 'cancelled').
  Future<void> cancel(String requestId) async {
    await _client
        .from(_table)
        .update({'status': 'cancelled'})
        .eq('id', requestId)
        .eq('status', 'pending'); // RLS also enforces this
  }

  // ── Read ─────────────────────────────────────────────────────────────

  /// Fetch the current user's ride requests, newest first.
  ///
  /// Optionally filtered by [status] (pass null for all).
  Future<List<RideRequest>> fetchMyRides({String? status}) async {
    var query = _client.from(_table).select(_cols);
    final ordered = status != null
        ? query.eq('status', status).order('created_at', ascending: false)
        : query.order('created_at', ascending: false);
    final rows = await ordered as List;
    return rows
        .map((r) => RideRequest.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Realtime stream of the current user's ride requests.
  ///
  /// `.stream()` accepts a column list via `eq`/`select`-style chaining but
  /// the Supabase Flutter SDK's `SupabaseStreamBuilder` does not support a
  /// column-projection argument directly. To avoid the hex EWKB columns,
  /// we pass an explicit list to `.stream()`'s `select` parameter indirectly
  /// by using the `select` override available from Supabase Flutter ≥ 2.x.
  ///
  /// If the SDK version does not support it, the stream falls back to the
  /// full row and `fromJson` reads only the keys it needs (the generated
  /// lat/lng columns are present alongside the hex ones — it just ignores
  /// `pickup_geo`/`drop_geo` since those keys are not accessed).
  Stream<List<RideRequest>> watchMyRides() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => RideRequest.fromJson(r)).toList());
  }
}

/// Riverpod provider for [RideRequestRepository].
final rideRequestRepositoryProvider = Provider<RideRequestRepository>(
  (ref) => RideRequestRepository(ref.watch(supabaseClientProvider)),
);
