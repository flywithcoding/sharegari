import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/features/ride_status/data/ride_status_models.dart';
import 'package:sharegari/features/ride_status/data/ride_status_repository.dart';

// ── Request status stream ────────────────────────────────────────────────────

/// Family provider: streams the status string for a single request.
///
/// Usage: `ref.watch(requestStatusStreamProvider('uuid-of-request'))`
final requestStatusStreamProvider =
    StreamProvider.family<String, String>((ref, requestId) {
  return ref.watch(rideStatusRepositoryProvider).watchRequestStatus(requestId);
});

// ── Group detail (async, refreshable) ────────────────────────────────────────

/// Family provider: loads the [GroupDetail] for a given request id.
///
/// Call `ref.refresh(groupDetailProvider(id))` after a Realtime event to
/// reload the full group snapshot (co-riders, driver, fare).
final groupDetailProvider =
    FutureProvider.family<GroupDetail?, String>((ref, requestId) {
  return ref.watch(rideStatusRepositoryProvider).fetchGroupDetail(requestId);
});

// ── Group status stream ──────────────────────────────────────────────────────

/// Family provider: streams the group status for a given group id.
///
/// Used to show live updates inside the status screen once the group id
/// is known.
final groupStatusStreamProvider =
    StreamProvider.family<String, String>((ref, groupId) {
  return ref.watch(rideStatusRepositoryProvider).watchGroupStatus(groupId);
});

// ── Full group row stream (for price drops & member changes) ────────────────

/// Family provider: streams the full `ride_groups` row for Realtime updates.
final groupStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, groupId) {
  return ref.watch(rideStatusRepositoryProvider).watchGroup(groupId);
});
