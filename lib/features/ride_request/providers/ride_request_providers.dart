import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/features/ride_request/data/ride_request_model.dart';
import 'package:sharegari/features/ride_request/data/ride_request_repository.dart';

/// Streams the current user's ride requests in real-time.
///
/// Used by [MyRidesScreen] to show a live list without manual refresh.
final myRidesProvider = StreamProvider<List<RideRequest>>(
  (ref) => ref.watch(rideRequestRepositoryProvider).watchMyRides(),
);
