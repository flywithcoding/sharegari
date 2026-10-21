import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/features/ride_request/data/ride_request_model.dart';
import 'package:sharegari/features/ride_status/data/ride_status_models.dart';
import 'package:sharegari/features/ride_status/data/ride_status_repository.dart';
import 'package:sharegari/features/ride_status/providers/ride_status_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RideStatusScreen — live status screen for a single ride request.
//
// Opens:
//   • Automatically after submitting a request (ride_request_screen pushes here)
//   • When the rider taps a request in My Rides
//
// Listens to:
//   • ride_requests Realtime  → request status changes
//   • ride_groups Realtime    → group status changes (after group formed)
//   • group_members (via fetch) → co-rider list, fare (re-fetched on change)
// ─────────────────────────────────────────────────────────────────────────────

class RideStatusScreen extends ConsumerStatefulWidget {
  const RideStatusScreen({
    super.key,
    required this.requestId,
    this.pickupAddress,
    this.dropAddress,
    this.estimatedSoloFare,
    this.estimatedShareFare,
    this.departAt,
  });

  final String requestId;
  // Optional: pre-filled for "try a different time" flow.
  final String? pickupAddress;
  final String? dropAddress;
  final double? estimatedSoloFare;
  final double? estimatedShareFare;
  final DateTime? departAt;

  @override
  ConsumerState<RideStatusScreen> createState() => _RideStatusScreenState();
}

class _RideStatusScreenState extends ConsumerState<RideStatusScreen> {
  bool _cancelLoading = false;

  @override
  void dispose() {
    super.dispose();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  /// Pop if there is something to pop to, otherwise go to My Rides.
  ///
  /// This is safe regardless of how the status screen was opened:
  ///   • Via context.push from My Rides → pop returns to My Rides.
  ///   • Via context.push from Ride Request (after submit) → pop returns
  ///     to Ride Request, which itself has pop to My Rides / Home.
  ///   • Via context.go (old code path, now fixed) → fallback to myRides.
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.myRides);
    }
  }

  // ── Cancel handler ────────────────────────────────────────────────────────

  Future<void> _handleCancel(RideRequestStatus currentStatus) async {
    final isMatched = currentStatus == RideRequestStatus.matched ||
        currentStatus == RideRequestStatus.confirmed;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isMatched ? 'Cancel after group formed?' : 'Cancel request?',
          style: const TextStyle(color: AppColors.onBackground),
        ),
        content: Text(
          isMatched
              ? 'Your group will be notified. If fewer than 2 riders remain, '
                'they will be re-queued to find a new group.\n\n'
                'No cancellation fee is charged at this stage.'
              : 'This will cancel your request. You can always make a new one.',
          style: const TextStyle(color: AppColors.onSurfaceMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel ride',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _cancelLoading = true);
    try {
      await ref
          .read(rideStatusRepositoryProvider)
          .cancelRequest(widget.requestId);
      if (!mounted) return;
      // After cancelling, go back to My Rides.
      // Use pop-or-go so the existing back stack is preserved.
      _goBack();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $e')),
      );
    } finally {
      if (mounted) setState(() => _cancelLoading = false);
    }
  }

  // ── Try again handler ─────────────────────────────────────────────────────

  void _tryAgain() {
    // Push the ride request form on top of the current stack so the user
    // can go back. context.go would replace the stack and lose My Rides.
    context.push(AppRoutes.rideRequest);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final statusAsync =
        ref.watch(requestStatusStreamProvider(widget.requestId));

    return statusAsync.when(
      loading: () => _scaffold(_loadingBody()),
      error: (e, _) => _scaffold(_errorBody('$e')),
      data: (statusStr) {
        final status = RideRequestStatus.fromString(statusStr);

        // Once matched, load group details
        if (status == RideRequestStatus.matched ||
            status == RideRequestStatus.confirmed ||
            status == RideRequestStatus.inProgress ||
            status == RideRequestStatus.completed) {
          return _scaffold(_groupBody(status));
        }
        if (status == RideRequestStatus.expired) {
          return _scaffold(_expiredBody());
        }
        if (status == RideRequestStatus.cancelled) {
          return _scaffold(_cancelledBody());
        }
        // searching / pending
        return _scaffold(_searchingBody(status));
      },
    );
  }

  Scaffold _scaffold(Widget body) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Ride Status'),
          // Always show a back button. Pop if there is a route to pop to
          // (e.g. My Rides or Ride Request pushed us here); otherwise fall
          // back to My Rides via go() so the app is never stranded.
          leading: BackButton(onPressed: _goBack),
          automaticallyImplyLeading: true,
        ),
        body: SafeArea(child: body),
      );

  // ── State bodies ──────────────────────────────────────────────────────────

  Widget _loadingBody() => const Center(
        child: CircularProgressIndicator(),
      );

  Widget _errorBody(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(msg,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center),
        ),
      );

  // ── 1. Searching ──────────────────────────────────────────────────────────

  Widget _searchingBody(RideRequestStatus status) {
    final solo  = widget.estimatedSoloFare;
    final share = widget.estimatedShareFare;
    final depart = widget.departAt;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Animated "Finding riders" indicator ─────────────────────────
          Center(
            child: Column(children: [
              const SizedBox(height: 16),
              _PulsingDot(),
              const SizedBox(height: 16),
              Text(
                'Finding riders...',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'We\'re matching you with others on the same route.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.onSurfaceMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ]),
          ),

          // ── Trip details ─────────────────────────────────────────────────
          _SectionCard(children: [
            if (widget.pickupAddress != null)
              _TripRow(
                icon: Icons.trip_origin_rounded,
                color: AppColors.primary,
                label: widget.pickupAddress!,
              ),
            if (widget.dropAddress != null) ...[
              const SizedBox(height: 12),
              _TripRow(
                icon: Icons.location_on_rounded,
                color: AppColors.secondary,
                label: widget.dropAddress!,
              ),
            ],
            if (depart != null) ...[
              const SizedBox(height: 12),
              _TripRow(
                icon: Icons.schedule_rounded,
                color: AppColors.onSurfaceMuted,
                label: DateFormat('EEE d MMM, h:mm a').format(depart),
              ),
            ],
          ]),

          // ── Fare estimate ────────────────────────────────────────────────
          if (share != null && solo != null) ...[
            const SizedBox(height: 16),
            _SectionCard(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimated shared fare',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    '৳${share.toStringAsFixed(0)}–৳${solo.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Final fare locked when your group is formed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ],

          const SizedBox(height: 32),

          // ── Cancel button ─────────────────────────────────────────────────
          if (_cancelLoading)
            const Center(child: CircularProgressIndicator())
          else
            OutlinedButton(
              onPressed: () => _handleCancel(status),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error),
              ),
              child: const Text('Cancel request'),
            ),
        ],
      ),
    );
  }

  // ── 2. Group formed ───────────────────────────────────────────────────────

  Widget _groupBody(RideRequestStatus reqStatus) {
    final groupAsync =
        ref.watch(groupDetailProvider(widget.requestId));

    return groupAsync.when(
      loading: () => _loadingBody(),
      error: (e, _) => _errorBody('$e'),
      data: (group) {
        if (group == null) {
          // Group not found yet — retry shortly
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              ref.invalidate(groupDetailProvider(widget.requestId));
            }
          });
          return _loadingBody();
        }

        // When the group status changes, refresh the whole group detail
        final groupStatusAsync =
            ref.watch(groupStatusStreamProvider(group.groupId));
        groupStatusAsync.whenData((gs) {
          if (group.status != GroupStatus.fromString(gs)) {
            ref.invalidate(groupDetailProvider(widget.requestId));
          }
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status header ──────────────────────────────────────────
              Center(
                child: Column(children: [
                  const SizedBox(height: 8),
                  _StatusIcon(status: group.status),
                  const SizedBox(height: 12),
                  Text(
                    group.status.label,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: _groupColor(group.status)),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),

              // ── My fare ───────────────────────────────────────────────
              _SectionCard(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Your locked fare',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '৳${group.myFare.toStringAsFixed(0)}',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontSize: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Departure',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      DateFormat('EEE d MMM, h:mm a').format(group.departAt),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: 16),

              // ── Co-riders ──────────────────────────────────────────────
              _SectionCard(children: [
                Row(
                  children: [
                    const Icon(Icons.people_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${group.riderCount} riders in your group',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                // Self first
                _RiderRow(
                  label: 'You',
                  pickupOrder: group.myPickupOrder,
                  fare: group.myFare,
                  isSelf: true,
                ),
                ...group.coRiders.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _RiderRow(
                      label: r.firstName,
                      pickupOrder: r.pickupOrder,
                      fare: r.fare,
                    ),
                  ),
                ),
              ]),

              // ── Driver (when assigned) ─────────────────────────────────
              if (group.driver != null) ...[
                const SizedBox(height: 16),
                _SectionCard(children: [
                  Row(children: [
                    const Icon(Icons.directions_car_rounded,
                        size: 18, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Text('Your driver',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(group.driver!.firstName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.primary)),
                        Text('${group.driver!.carModel}  •  ${group.driver!.plate}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(group.driver!.rating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ],
                  ),
                ]),
              ],

              const SizedBox(height: 32),

              // ── Cancel (only while matching/pending driver) ────────────
              if (reqStatus == RideRequestStatus.matched ||
                  reqStatus == RideRequestStatus.searching)
                if (_cancelLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  OutlinedButton(
                    onPressed: () => _handleCancel(reqStatus),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Cancel ride'),
                  ),
            ],
          ),
        );
      },
    );
  }

  Color _groupColor(GroupStatus s) => switch (s) {
        GroupStatus.forming        => AppColors.primary,
        GroupStatus.pendingDriver  => AppColors.primary,
        GroupStatus.driverAssigned => AppColors.secondary,
        GroupStatus.confirmed      => Colors.green,
        GroupStatus.inProgress     => Colors.blue,
        GroupStatus.completed      => AppColors.onSurfaceMuted,
        GroupStatus.cancelled      => AppColors.error,
      };

  // ── 3. Expired ────────────────────────────────────────────────────────────

  Widget _expiredBody() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Center(
              child: Column(children: [
                Icon(Icons.hourglass_disabled_rounded,
                    size: 64, color: AppColors.onSurfaceMuted),
                const SizedBox(height: 16),
                Text(
                  'No match found',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.onSurfaceMuted),
                ),
                const SizedBox(height: 8),
                Text(
                  'We couldn\'t find a matching group before your departure time.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _tryAgain,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try a different time'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.myRides),
              child: const Text('Back to My Rides'),
            ),
          ],
        ),
      );

  // ── 4. Cancelled ──────────────────────────────────────────────────────────

  Widget _cancelledBody() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Center(
              child: Column(children: [
                Icon(Icons.cancel_outlined, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Ride cancelled',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: AppColors.error)),
              ]),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _tryAgain,
              child: const Text('Book a new ride'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.myRides),
              child: const Text('Back to My Rides'),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Animated pulsing dot for the "searching" state.
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: const Icon(Icons.people_rounded,
              size: 36, color: AppColors.primary),
        ),
      );
}

/// Icon representing the group status.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final GroupStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      GroupStatus.forming        => (Icons.people_rounded, AppColors.primary),
      GroupStatus.pendingDriver  => (Icons.directions_car_rounded, AppColors.primary),
      GroupStatus.driverAssigned => (Icons.directions_car_rounded, AppColors.secondary),
      GroupStatus.confirmed      => (Icons.check_circle_rounded, Colors.green),
      GroupStatus.inProgress     => (Icons.navigation_rounded, Colors.blue),
      GroupStatus.completed      => (Icons.flag_rounded, AppColors.onSurfaceMuted),
      GroupStatus.cancelled      => (Icons.cancel_rounded, AppColors.error),
    };
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 36, color: color),
    );
  }
}

/// A card-like container for section content.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}

/// Pickup / drop-off / time row.
class _TripRow extends StatelessWidget {
  const _TripRow(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

/// A single rider row inside the co-riders card.
class _RiderRow extends StatelessWidget {
  const _RiderRow({
    required this.label,
    required this.pickupOrder,
    required this.fare,
    this.isSelf = false,
  });
  final String label;
  final int pickupOrder;
  final double fare;
  final bool isSelf;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isSelf
                  ? AppColors.primary.withAlpha(40)
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$pickupOrder',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelf ? AppColors.primary : AppColors.onSurfaceMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelf ? FontWeight.w700 : FontWeight.w400,
                    color: isSelf
                        ? AppColors.onBackground
                        : AppColors.onSurfaceMuted,
                  ),
            ),
          ),
          Text(
            '৳${fare.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      );
}
