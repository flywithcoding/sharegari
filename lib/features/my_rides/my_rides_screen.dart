import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_motion.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/core/widgets/pressable_scale.dart';
import 'package:sharegari/features/ride_request/data/ride_request_model.dart';
import 'package:sharegari/features/ride_request/data/ride_request_repository.dart';
import 'package:sharegari/features/ride_request/providers/ride_request_providers.dart';

/// My Rides screen — real-time list of the current user's ride requests.
///
/// Styled as modern ticket-style cards with route tracking, live status,
/// and perforated dividers.
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Rides'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
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
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _filters.entries.map((e) {
                  final selected = _filterStatus == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PressableScale(
                      onTap: () => setState(() => _filterStatus = e.key),
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        curve: AppMotion.stateChangeCurve,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: AppRadii.pill,
                          boxShadow: selected ? AppShadows.soft : null,
                        ),
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
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
            const SizedBox(height: 6),

            // ── Rides list ───────────────────────────────────────────
            Expanded(
              child: ridesAsync.when(
                loading: () => _buildSkeletonLoading(),
                error: (err, stack) => _ErrorState(error: err.toString()),
                data: (allRides) {
                  final rides = _filterStatus == null
                      ? allRides
                      : allRides
                          .where((r) =>
                              r.status.name == _filterStatus ||
                              _dbStatus(r.status) == _filterStatus)
                          .toList();

                  if (rides.isEmpty) return _EmptyState(filter: _filterStatus);

                  final reducedMotion = AppMotion.isReducedMotion(context);

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async =>
                        ref.invalidate(myRidesProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: rides.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (_, index) {
                        final ride = rides[index];
                        Widget cardItem = PressableScale(
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

                        if (!reducedMotion && index < 8) {
                          cardItem = cardItem
                              .animate(delay: (40 * index).ms)
                              .fadeIn(duration: AppMotion.normal, curve: AppMotion.entranceCurve)
                              .slideY(begin: 0.08, end: 0, duration: AppMotion.normal, curve: AppMotion.entranceCurve);
                        }

                        return cardItem;
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

  Widget _buildSkeletonLoading() {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 3,
        separatorBuilder: (_, index) => const SizedBox(height: 14),
        itemBuilder: (_, index) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadii.card,
            boxShadow: AppShadows.card,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Bone(
                    width: 100,
                    height: 24,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                  ),
                  Spacer(),
                  Bone(
                    width: 70,
                    height: 24,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                  ),
                ],
              ),
              SizedBox(height: 18),
              Bone.text(words: 5),
              SizedBox(height: 14),
              Bone.text(words: 5),
              SizedBox(height: 18),
              Row(
                children: [
                  Bone.text(words: 3),
                  Spacer(),
                  Bone(
                    width: 80,
                    height: 28,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              child: const Text('Cancel ride',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600))),
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

// ── Modern Ticket-Style Ride Card ─────────────────────────────────────────────

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride, required this.onCancel});
  final RideRequest ride;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dateStr =
        DateFormat('EEE, d MMM · hh:mm a').format(ride.departAt);

    final fareValue = ride.estimatedShareFare != null
        ? '৳${ride.estimatedShareFare!.toStringAsFixed(0)}'
        : (ride.estimatedSoloFare != null
            ? '৳${ride.estimatedSoloFare!.toStringAsFixed(0)}'
            : '—');

    return Hero(
      tag: 'ride_card_${ride.id}',
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadii.card,
            boxShadow: AppShadows.ticket,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Ticket Header ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.pill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: tt.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: ride.status),
                  ],
                ),
              ),

              // ── 2. Perforated Ticket Divider ───────────────────────────
              const _TicketPerforationLine(),

              // ── 3. Route Line & Addresses ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vertical route track
                    Column(
                      children: [
                        const SizedBox(height: 3),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 26,
                          color: AppColors.timelineTrack,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Pickup & Drop
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.pickupAddress,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onBackground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            ride.dropAddress,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onBackground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Flexibility badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.pill,
                      ),
                      child: Text(
                        '±${ride.windowMin} min flexibility',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 4. Ticket Footer (Price & Action) ───────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EST. PER RIDER',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fareValue,
                          style: tt.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    if (ride.status == RideRequestStatus.searching ||
                        ride.status == RideRequestStatus.pending)
                      TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.error),
                        label: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                        ),
                      )
                    else
                      Row(
                        children: const [
                          Text(
                            'View status',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 16, color: AppColors.primary),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Perforated Ticket Line with Notches ────────────────────────────────────────

class _TicketPerforationLine extends StatelessWidget {
  const _TicketPerforationLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        children: [
          // Left ticket notch
          Container(
            width: 8,
            height: 16,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius:
                  BorderRadius.horizontal(right: Radius.circular(8)),
            ),
          ),
          // Dashed perforation line
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: CustomPaint(
                painter: const _DashedLinePainter(color: AppColors.ticketDotted),
                size: const Size(double.infinity, 1),
              ),
            ),
          ),
          // Right ticket notch
          Container(
            width: 8,
            height: 16,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius:
                  BorderRadius.horizontal(left: Radius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final RideRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor) = switch (status) {
      RideRequestStatus.searching  =>
        (AppColors.primaryDark, AppColors.primaryTint),
      RideRequestStatus.pending    =>
        (AppColors.primaryDark, AppColors.primaryTint),
      RideRequestStatus.matched    =>
        (AppColors.badgeWarning, AppColors.badgeWarningTint),
      RideRequestStatus.confirmed  =>
        (AppColors.primaryDark, AppColors.primaryTint),
      RideRequestStatus.inProgress =>
        (AppColors.badgeInfo, AppColors.badgeInfoTint),
      RideRequestStatus.completed  =>
        (AppColors.onSurfaceMuted, AppColors.surfaceVariant),
      RideRequestStatus.cancelled  =>
        (AppColors.error, AppColors.errorTint),
      RideRequestStatus.expired    =>
        (AppColors.onSurfaceMuted, AppColors.surfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / Error States ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.filter});
  final String? filter;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _EmptyRidesIllustration(),
            const SizedBox(height: 24),
            Text(
              filter == null ? 'No rides yet' : 'No ${filter!} rides',
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              filter == null
                  ? 'Your scheduled trips and daily carpools will appear here as tickets.'
                  : 'Try selecting another status tab above to see your other requests.',
              style: tt.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (filter == null) ...[
              const SizedBox(height: 24),
              PressableScale(
                child: SizedBox(
                  width: 220,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.rideRequest),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Request a Ride'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Custom illustration built exclusively from Flutter shapes & icons.
class _EmptyRidesIllustration extends StatelessWidget {
  const _EmptyRidesIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer subtle aura ring
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryTint.withAlpha(70),
            ),
          ),
          // Middle glowing ring
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryTint,
            ),
          ),
          // Center white circle with shadow
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              boxShadow: AppShadows.soft,
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          // Floating secondary pin badge top-right
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.secondaryTint,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.secondary,
                size: 16,
              ),
            ),
          ),
          // Floating star badge bottom-left
          Positioned(
            bottom: 16,
            left: 14,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: AppColors.onPrimary,
                size: 14,
              ),
            ),
          ),
        ],
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
