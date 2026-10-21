import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/features/ride_request/data/ride_request_model.dart';
import 'package:sharegari/features/ride_request/data/ride_request_repository.dart';
import 'package:sharegari/features/ride_request/providers/ride_request_providers.dart';

/// My Rides screen — real-time list of the current user's ride requests.
///
/// Streams from Supabase Realtime so status updates (pending → matched, etc.)
/// are reflected immediately without any manual refresh.
class MyRidesScreen extends ConsumerStatefulWidget {
  const MyRidesScreen({super.key});

  @override
  ConsumerState<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends ConsumerState<MyRidesScreen> {
  /// null = show all; otherwise filter by this status string.
  String? _filterStatus;

  static const _filters = <String?, String>{
    null: 'All',
    'searching': 'Finding',
    'matched': 'Matched',
    'confirmed': 'Confirmed',
    'in_progress': 'Active',
    'completed': 'Done',
    'cancelled': 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(myRidesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New request',
            onPressed: () => context.push(AppRoutes.rideRequest),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status filter chips ──────────────────────────────────
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _filters.entries.map((e) {
                  final selected = _filterStatus == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filterStatus = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? AppColors.onPrimary
                                : AppColors.onSurfaceMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),

            // ── Rides list ───────────────────────────────────────────
            Expanded(
              child: ridesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, stack) => _ErrorState(error: err.toString()),
                data: (allRides) {
                  // Apply filter
                  final rides = _filterStatus == null
                      ? allRides
                      : allRides
                          .where((r) =>
                              r.status.name == _filterStatus ||
                              // map enum names to DB strings
                              _dbStatus(r.status) == _filterStatus)
                          .toList();

                  if (rides.isEmpty) return _EmptyState(filter: _filterStatus);

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async =>
                        ref.invalidate(myRidesProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: rides.length,
                      separatorBuilder: (_, i) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final ride = rides[i];
                        return GestureDetector(
                          onTap: () => context.push(
                            AppRoutes.rideStatusPath(ride.id),
                            extra: <String, dynamic>{
                              'pickupAddress':     ride.pickupAddress,
                              'dropAddress':       ride.dropAddress,
                              'estimatedSoloFare': ride.estimatedSoloFare,
                              'estimatedShareFare':ride.estimatedShareFare,
                              'departAt':          ride.departAt.toUtc().toIso8601String(),
                            },
                          ),
                          child: _RideCard(
                            ride: ride,
                            onCancel: () => _cancelRide(ride),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps [RideRequestStatus] enum value → Postgres status string.
  String _dbStatus(RideRequestStatus s) => switch (s) {
        RideRequestStatus.searching  => 'searching',
        RideRequestStatus.pending    => 'pending',
        RideRequestStatus.matched    => 'matched',
        RideRequestStatus.confirmed  => 'confirmed',
        RideRequestStatus.inProgress => 'in_progress',
        RideRequestStatus.completed  => 'completed',
        RideRequestStatus.cancelled  => 'cancelled',
        RideRequestStatus.expired    => 'expired',
      };

  Future<void> _cancelRide(RideRequest ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel ride?'),
        content: const Text(
            'This will cancel your pending request. You can always make a new one.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Cancel ride',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(rideRequestRepositoryProvider).cancel(ride.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $e')),
      );
    }
  }
}

// ── Ride card ────────────────────────────────────────────────────────────────

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride, required this.onCancel});
  final RideRequest ride;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dateStr =
        DateFormat('EEE, d MMM · hh:mm a').format(ride.departAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusBorderColor(ride.status).withAlpha(80),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge + date + chevron row
          Row(
            children: [
              _StatusBadge(status: ride.status),
              const Spacer(),
              Text(dateStr,
                  style: tt.bodySmall
                      ?.copyWith(color: AppColors.onSurfaceMuted)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.onSurfaceMuted),
            ],
          ),
          const SizedBox(height: 12),

          // Route
          _RouteRow(
            icon: Icons.my_location_rounded,
            color: AppColors.primary,
            label: ride.pickupAddress,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: SizedBox(
              height: 14,
              child: VerticalDivider(
                  color: AppColors.surfaceVariant, thickness: 1.5),
            ),
          ),
          _RouteRow(
            icon: Icons.location_on_rounded,
            color: AppColors.secondary,
            label: ride.dropAddress,
          ),

          // Flexibility
          const SizedBox(height: 10),
          Text('±${ride.windowMin} min flexibility',
              style: tt.bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),

          // Fare estimates (if available)
          if (ride.estimatedShareFare != null) ...[
            const SizedBox(height: 6),
            Text(
              'Est. shared fare: ৳${ride.estimatedShareFare!.toStringAsFixed(0)}',
              style: tt.bodySmall?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ],

          // Cancel button (only for pending)
          if (ride.status == RideRequestStatus.searching ||
              ride.status == RideRequestStatus.pending) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined,
                    size: 16, color: AppColors.error),
                label: Text('Cancel',
                    style: TextStyle(color: AppColors.error, fontSize: 13)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusBorderColor(RideRequestStatus s) => switch (s) {
        RideRequestStatus.searching => AppColors.primary,
        RideRequestStatus.pending   => AppColors.primary,
        RideRequestStatus.matched   => Colors.amber,
        RideRequestStatus.confirmed => Colors.green,
        RideRequestStatus.inProgress => Colors.blue,
        RideRequestStatus.completed => AppColors.onSurfaceMuted,
        RideRequestStatus.cancelled => AppColors.error,
        RideRequestStatus.expired   => AppColors.onSurfaceMuted,
      };
}

class _RouteRow extends StatelessWidget {
  const _RouteRow(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final RideRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      RideRequestStatus.searching  => (AppColors.primary, AppColors.primary),
      RideRequestStatus.pending    => (AppColors.primary, AppColors.primary),
      RideRequestStatus.matched    => (Colors.amber.shade700, Colors.amber),
      RideRequestStatus.confirmed  => (Colors.green.shade700, Colors.green),
      RideRequestStatus.inProgress => (Colors.blue.shade700, Colors.blue),
      RideRequestStatus.completed  =>
        (AppColors.onSurfaceMuted, AppColors.surfaceVariant),
      RideRequestStatus.cancelled  =>
        (AppColors.error, AppColors.error),
      RideRequestStatus.expired    =>
        (AppColors.onSurfaceMuted, AppColors.surfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withAlpha(30),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: bg.withAlpha(100)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Empty / error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.filter});
  final String? filter;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car_outlined,
                size: 64, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 16),
            Text(
              filter == null ? 'No rides yet' : 'No ${filter!} rides',
              style: tt.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              filter == null
                  ? 'Tap the + button or the FAB on Home to request your first shared ride.'
                  : 'Try a different filter.',
              style: tt.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 16),
            Text('Could not load rides',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
