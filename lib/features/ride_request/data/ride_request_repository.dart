import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sharegari/core/supabase/supabase_client_provider.dart';
import 'package:sharegari/features/ride_request/data/ride_request_model.dart';

/// Thin data-access layer for `public.ride_requests`.
class RideRequestRepository {
  RideRequestRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'ride_requests';

  // ── Write ────────────────────────────────────────────────────────────

  /// Insert a new ride request.
  ///
  /// Returns the inserted row as a [RideRequest] on success.
  /// Throws [PostgrestException] on database errors (let callers handle UI).
  Future<RideRequest> insert(RideRequest request) async {
    final rows = await _client
        .from(_table)
        .insert(request.toInsertJson())
        .select()
        .single();
    return RideRequest.fromJson(rows);
  }

  /// Cancel a pending request by setting status = 'cancelled'.
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
    var query = _client.from(_table).select();
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
  /// Emits a new list whenever any row changes (INSERT, UPDATE, DELETE).
  Stream<List<RideRequest>> watchMyRides() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) =>
            rows.map((r) => RideRequest.fromJson(r)).toList());
  }
}

/// Riverpod provider for [RideRequestRepository].
final rideRequestRepositoryProvider = Provider<RideRequestRepository>(
  (ref) => RideRequestRepository(ref.watch(supabaseClientProvider)),
);
