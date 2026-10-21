import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sharegari/core/supabase/supabase_client_provider.dart';
import 'package:sharegari/features/ride_status/data/ride_status_models.dart';

/// Data-access layer for the rider status screen.
///
/// Combines data from ride_requests, ride_groups, group_members,
/// my_group_co_riders (view), and drivers/users.
class RideStatusRepository {
  RideStatusRepository(this._client);

  final SupabaseClient _client;

  // ── Fetch: single request status ────────────────────────────────────────

  /// Fetches the status string for a single request.
  Future<String> fetchRequestStatus(String requestId) async {
    final row = await _client
        .from('ride_requests')
        .select('status')
        .eq('id', requestId)
        .single();
    return row['status'] as String;
  }

  // ── Fetch: group detail for a matched request ────────────────────────────

  /// Returns full [GroupDetail] for [requestId] if it is matched/confirmed/etc.
  /// Returns null if the request is not yet in a group.
  Future<GroupDetail?> fetchGroupDetail(String requestId) async {
    // 1. Find the group_member row for this request
    final memberRows = await _client
        .from('group_members')
        .select('group_id, fare, pickup_order, dropoff_order')
        .eq('request_id', requestId)
        .neq('status', 'cancelled');

    if (memberRows.isEmpty) return null;
    final myMember = memberRows.first;
    final groupId   = myMember['group_id'] as String;
    final myFare    = (myMember['fare'] as num).toDouble();
    final myPickup  = myMember['pickup_order'] as int;

    // 2. Fetch the group row
    final groupRow = await _client
        .from('ride_groups')
        .select('id, status, depart_at, fare_total, driver_id')
        .eq('id', groupId)
        .single();

    final groupStatus = GroupStatus.fromString(groupRow['status'] as String);
    final departAt    = DateTime.parse(groupRow['depart_at'] as String).toLocal();
    final fareTotal   = (groupRow['fare_total'] as num?)?.toDouble() ?? 0.0;
    final driverId    = groupRow['driver_id'] as String?;

    // 3. Fetch co-riders (first name only via the view)
    final coRiderRows = await _client
        .from('my_group_co_riders')
        .select('request_id, first_name, pickup_order, dropoff_order, fare')
        .eq('group_id', groupId)
        .neq('request_id', requestId); // exclude self

    final coRiders = (coRiderRows as List)
        .map((r) => CoRider.fromJson(r as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.pickupOrder.compareTo(b.pickupOrder));

    // 4. Fetch driver (only if assigned)
    DriverDetail? driver;
    if (driverId != null) {
      try {
        final driverRow = await _client
            .from('drivers')
            .select('car_model, plate, users!inner(name, rating)')
            .eq('user_id', driverId)
            .single();
        final userMap = (driverRow['users'] as Map<String, dynamic>);
        driver = DriverDetail.fromJson({
          'name':      userMap['name'],
          'rating':    userMap['rating'],
          'car_model': driverRow['car_model'],
          'plate':     driverRow['plate'],
        });
      } catch (_) {
        // Driver not yet visible; leave null
      }
    }

    return GroupDetail(
      groupId:       groupId,
      status:        groupStatus,
      departAt:      departAt,
      fareTotal:     fareTotal,
      myFare:        myFare,
      myPickupOrder: myPickup,
      coRiders:      coRiders,
      driver:        driver,
    );
  }

  // ── Realtime streams ─────────────────────────────────────────────────────

  /// Emits the request's status string every time it changes.
  Stream<String> watchRequestStatus(String requestId) {
    return _client
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .map<String>((rows) {
          if (rows.isEmpty) return 'searching';
          return rows.first['status'] as String? ?? 'searching';
        });
  }

  /// Emits the group status string whenever the group row changes.
  Stream<String> watchGroupStatus(String groupId) {
    return _client
        .from('ride_groups')
        .stream(primaryKey: ['id'])
        .eq('id', groupId)
        .map<String>((rows) {
          if (rows.isEmpty) return 'pending_driver';
          return rows.first['status'] as String? ?? 'pending_driver';
        });
  }

  // ── Cancel ───────────────────────────────────────────────────────────────

  /// Calls the `cancel_ride_request` SQL function.
  ///
  /// Returns true if the group was dissolved (other riders re-queued).
  Future<bool> cancelRequest(String requestId) async {
    final result = await _client.rpc(
      'cancel_ride_request',
      params: {'p_request_id': requestId},
    );
    final json = result as Map<String, dynamic>;
    return json['group_dissolved'] as bool? ?? false;
  }
}

/// Riverpod provider for [RideStatusRepository].
final rideStatusRepositoryProvider = Provider<RideStatusRepository>(
  (ref) => RideStatusRepository(ref.watch(supabaseClientProvider)),
);
