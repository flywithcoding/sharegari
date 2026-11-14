import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_motion.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/core/widgets/pressable_scale.dart';
import 'package:sharegari/features/ride_request/data/ride_request_model.dart';
import 'package:sharegari/features/ride_status/data/ride_status_models.dart';
import 'package:sharegari/features/ride_status/data/ride_status_repository.dart';
import 'package:sharegari/features/ride_status/providers/ride_status_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RideStatusScreen — live status screen for a single ride request.
//
// Shows a modern vertical timeline of booking states, live group details,
// route ticket info, and driver assignment.
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

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.myRides);
    }
  }

  Future<void> _handleCancel(RideRequestStatus currentStatus) async {
    final isMatched = currentStatus == RideRequestStatus.matched ||
        currentStatus == RideRequestStatus.confirmed;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.dialog,
        ),
        title: Text(
          isMatched ? 'Cancel after group formed?' : 'Cancel request?',
          style: const TextStyle(
              color: AppColors.onBackground, fontWeight: FontWeight.w700),
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
            child: const Text(
              'Cancel ride',
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.w600),
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

  void _tryAgain() {
    context.push(AppRoutes.rideRequest);
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync =
        ref.watch(requestStatusStreamProvider(widget.requestId));

    Widget bodyWidget;
    String statusKey;

    if (statusAsync.isLoading) {
      statusKey = 'loading';
      bodyWidget = _loadingBody();
    } else if (statusAsync.hasError) {
      statusKey = 'error';
      bodyWidget = _errorBody('${statusAsync.error}');
    } else {
      final statusStr = statusAsync.value ?? '';
      final status = RideRequestStatus.fromString(statusStr);
      statusKey = statusStr;

      if (status == RideRequestStatus.matched ||
          status == RideRequestStatus.confirmed ||
          status == RideRequestStatus.inProgress ||
          status == RideRequestStatus.completed) {
        bodyWidget = _groupBody(status);
      } else if (status == RideRequestStatus.expired) {
        bodyWidget = _expiredBody();
      } else if (status == RideRequestStatus.cancelled) {
        bodyWidget = _cancelledBody();
      } else {
        bodyWidget = _searchingBody(status);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ride Status'),
        leading: BackButton(onPressed: _goBack),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppMotion.normal,
          switchInCurve: AppMotion.entranceCurve,
          switchOutCurve: AppMotion.stateChangeCurve,
          transitionBuilder: (child, animation) {
            if (AppMotion.isReducedMotion(context)) {
              return child;
            }
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(statusKey),
            child: bodyWidget,
          ),
        ),
      ),
    );
  }

  // ── Skeletons & Errors ────────────────────────────────────────────────────

  Widget _loadingBody() => Skeletonizer(
        enabled: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Column(children: [
                  Bone.circle(size: 64),
                  SizedBox(height: 14),
                  Bone.text(words: 2, fontSize: 22),
                  SizedBox(height: 8),
                  Bone.text(words: 5, fontSize: 13),
                ]),
              ),
              const SizedBox(height: 24),
              _SectionCard(children: const [
                Bone.text(words: 4),
                SizedBox(height: 14),
                Bone.text(words: 4),
                SizedBox(height: 14),
                Bone.text(words: 3),
              ]),
              const SizedBox(height: 16),
              _SectionCard(children: const [
                Bone.text(words: 3),
                SizedBox(height: 8),
                Bone.text(words: 5),
              ]),
            ],
          ),
        ),
      );

  Widget _errorBody(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(msg,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center),
        ),
      );

  // ── 1. Searching Body ─────────────────────────────────────────────────────

  Widget _searchingBody(RideRequestStatus status) {
    final solo = widget.estimatedSoloFare;
    final share = widget.estimatedShareFare;
    final depart = widget.departAt;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Vertical State Timeline ────────────────────────────────────
          _VerticalStateTimelineCard(
            currentStatus: status,
          ),
          const SizedBox(height: 20),

          // ── Trip Details Card with Hero ────────────────────────────────
          Hero(
            tag: 'ride_card_${widget.requestId}',
            child: Material(
              type: MaterialType.transparency,
              child: _SectionCard(
                title: 'Trip Route',
                children: [
                  if (widget.pickupAddress != null)
                    _TripRow(
                      icon: Icons.trip_origin_rounded,
                      color: AppColors.primary,
                      label: widget.pickupAddress!,
                    ),
                  if (widget.dropAddress != null) ...[
                    const SizedBox(height: 14),
                    _TripRow(
                      icon: Icons.location_on_rounded,
                      color: AppColors.secondary,
                      label: widget.dropAddress!,
                    ),
                  ],
                  if (depart != null) ...[
                    const SizedBox(height: 14),
                    _TripRow(
                      icon: Icons.schedule_rounded,
                      color: AppColors.onSurfaceMuted,
                      label: DateFormat('EEE d MMM, h:mm a').format(depart),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Fare Estimate Card ─────────────────────────────────────────
          if (share != null && solo != null) ...[
            _SectionCard(
              title: 'Fare Estimation',
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Est. shared fare per person',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '৳${share.toStringAsFixed(0)}–৳${solo.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Final fare is locked when group cut-off time is reached.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],

          // ── Cancel Button ──────────────────────────────────────────────
          if (_cancelLoading)
            const Center(child: CircularProgressIndicator())
          else
            PressableScale(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _handleCancel(status),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Cancel request'),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── 2. Group Formed Body ──────────────────────────────────────────────────

  Widget _groupBody(RideRequestStatus reqStatus) {
    final groupAsync = ref.watch(groupDetailProvider(widget.requestId));

    return groupAsync.when(
      loading: () => _loadingBody(),
      error: (e, _) => _errorBody('$e'),
      data: (group) {
        if (group == null) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              ref.invalidate(groupDetailProvider(widget.requestId));
            }
          });
          return _loadingBody();
        }

        final groupStreamAsync = ref.watch(groupStreamProvider(group.groupId));
        groupStreamAsync.whenData((row) {
          if (row.isNotEmpty) {
            final newStatus = row['status'] as String?;
            final newFareTotal = (row['fare_total'] as num?)?.toDouble();
            final newCurrentFare = (row['current_fare'] as num?)?.toDouble();
            if (group.status != GroupStatus.fromString(newStatus ?? '') ||
                group.fareTotal != newFareTotal ||
                group.currentFare != newCurrentFare) {
              ref.invalidate(groupDetailProvider(widget.requestId));
            }
          }
        });

        final cutoff = group.cutoffAt ??
            group.departAt.subtract(const Duration(minutes: 120));
        final cutoffTimeStr = DateFormat('h:mm a').format(cutoff);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Vertical State Timeline ────────────────────────────────
              _VerticalStateTimelineCard(
                currentStatus: reqStatus,
                groupStatus: group.status,
                riderCount: group.riderCount,
                cutoffTimeStr: cutoffTimeStr,
                driverName: group.driver?.firstName,
                carDetails: group.driver != null
                    ? '${group.driver!.carModel} • ${group.driver!.plate}'
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Live Open Group Banner ─────────────────────────────────
              if (group.status == GroupStatus.open) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: AppRadii.card,
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Group open: '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: _AnimatedRiderCount(
                                  count: group.riderCount,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' of 4 riders, current price ৳${group.displayFare.toStringAsFixed(0)}, may drop as riders join. Confirmed at $cutoffTimeStr',
                              ),
                            ],
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Fare & Departure Card ──────────────────────────────────
              _SectionCard(
                title: 'Fare & Schedule',
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        group.status == GroupStatus.open
                            ? 'Current price (may drop)'
                            : 'Your locked fare',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '৳${group.displayFare.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 28,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Departure',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        DateFormat('EEE d MMM, h:mm a').format(group.departAt),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  if (group.status == GroupStatus.open) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cut-off time',
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          cutoffTimeStr,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── Co-Riders Card ─────────────────────────────────────────
              _SectionCard(
                title: 'Co-Riders in Group',
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      _AnimatedRiderCount(
                        count: group.riderCount,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        ' riders matched',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _RiderRow(
                    label: 'You',
                    pickupOrder: group.myPickupOrder,
                    fare: group.myFare,
                    isSelf: true,
                  ),
                  ...group.coRiders.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _RiderRow(
                        label: r.firstName,
                        pickupOrder: r.pickupOrder,
                        fare: r.fare,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Driver Card (when assigned) ────────────────────────────
              if (group.driver != null) ...[
                _SectionCard(
                  title: 'Assigned Driver',
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.driver!.firstName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${group.driver!.carModel} • ${group.driver!.plate}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: 2),
                            Text(
                              group.driver!.rating.toStringAsFixed(1),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // ── Cancel Button ──────────────────────────────────────────
              if (reqStatus == RideRequestStatus.matched ||
                  reqStatus == RideRequestStatus.searching)
                if (_cancelLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  PressableScale(
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _handleCancel(reqStatus),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        child: const Text('Cancel ride'),
                      ),
                    ),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ── 3. Expired Body ───────────────────────────────────────────────────────

  Widget _expiredBody() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _VerticalStateTimelineCard(
              currentStatus: RideRequestStatus.expired,
            ),
            const SizedBox(height: 28),
            Center(
              child: Column(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_disabled_rounded,
                      size: 32, color: AppColors.onSurfaceMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  'No match found',
                  style: Theme.of(context).textTheme.headlineSmall,
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
            const Spacer(),
            PressableScale(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _tryAgain,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try a different time'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PressableScale(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _goBack,
                  child: const Text('Back to My Rides'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );

  // ── 4. Cancelled Body ─────────────────────────────────────────────────────

  Widget _cancelledBody() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _VerticalStateTimelineCard(
              currentStatus: RideRequestStatus.cancelled,
            ),
            const SizedBox(height: 28),
            Center(
              child: Column(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.errorTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      size: 32, color: AppColors.error),
                ),
                const SizedBox(height: 16),
                Text('Ride cancelled',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: AppColors.error)),
              ]),
            ),
            const Spacer(),
            PressableScale(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _tryAgain,
                  child: const Text('Book a new ride'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PressableScale(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _goBack,
                  child: const Text('Back to My Rides'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Vertical State Timeline Component
// ─────────────────────────────────────────────────────────────────────────────

enum _TimelineStepState { completed, active, upcoming, failed }

class _VerticalStateTimelineCard extends StatelessWidget {
  const _VerticalStateTimelineCard({
    required this.currentStatus,
    this.groupStatus,
    this.riderCount,
    this.cutoffTimeStr,
    this.driverName,
    this.carDetails,
  });

  final RideRequestStatus currentStatus;
  final GroupStatus? groupStatus;
  final int? riderCount;
  final String? cutoffTimeStr;
  final String? driverName;
  final String? carDetails;

  @override
  Widget build(BuildContext context) {
    // 5 progressive steps
    // 1. Request Placed
    // 2. Co-Rider Pool
    // 3. Driver & Fare Lock
    // 4. Trip En Route
    // 5. Destination Arrived

    final step1State = _TimelineStepState.completed;
    final step1Sub = 'Route and departure window registered';

    _TimelineStepState step2State;
    String step2Sub;

    if (currentStatus == RideRequestStatus.searching ||
        currentStatus == RideRequestStatus.pending) {
      step2State = _TimelineStepState.active;
      step2Sub = 'Searching for co-riders on your corridor...';
    } else if (currentStatus == RideRequestStatus.expired) {
      step2State = _TimelineStepState.failed;
      step2Sub = 'No match found before departure cutoff';
    } else if (currentStatus == RideRequestStatus.cancelled) {
      step2State = _TimelineStepState.failed;
      step2Sub = 'Ride request cancelled';
    } else if (groupStatus == GroupStatus.open) {
      step2State = _TimelineStepState.active;
      step2Sub = 'Group open: ${riderCount ?? 2} of 4 riders joined';
    } else {
      step2State = _TimelineStepState.completed;
      step2Sub = 'Group formed (${riderCount ?? 4} riders)';
    }

    _TimelineStepState step3State;
    String step3Sub;

    if (step2State == _TimelineStepState.failed ||
        currentStatus == RideRequestStatus.searching ||
        currentStatus == RideRequestStatus.pending) {
      step3State = _TimelineStepState.upcoming;
      step3Sub = 'Assigns after group cut-off time';
    } else if (groupStatus == GroupStatus.pendingDriver) {
      step3State = _TimelineStepState.active;
      step3Sub = 'Fare locked. Assigning nearest driver...';
    } else if (groupStatus == GroupStatus.driverAssigned ||
        groupStatus == GroupStatus.confirmed) {
      step3State = _TimelineStepState.completed;
      step3Sub = driverName != null
          ? '$driverName • $carDetails'
          : 'Driver assigned';
    } else if (groupStatus == GroupStatus.inProgress ||
        groupStatus == GroupStatus.completed) {
      step3State = _TimelineStepState.completed;
      step3Sub = driverName != null
          ? '$driverName • $carDetails'
          : 'Driver assigned';
    } else {
      step3State = _TimelineStepState.upcoming;
      step3Sub = cutoffTimeStr != null
          ? 'Locks at $cutoffTimeStr'
          : 'Cut-off assignment';
    }

    _TimelineStepState step4State;
    String step4Sub;

    if (groupStatus == GroupStatus.inProgress) {
      step4State = _TimelineStepState.active;
      step4Sub = 'Car en route to pickup and drop-offs';
    } else if (groupStatus == GroupStatus.completed) {
      step4State = _TimelineStepState.completed;
      step4Sub = 'Trip completed';
    } else {
      step4State = _TimelineStepState.upcoming;
      step4Sub = 'Scheduled departure';
    }

    _TimelineStepState step5State;
    String step5Sub;

    if (groupStatus == GroupStatus.completed) {
      step5State = _TimelineStepState.completed;
      step5Sub = 'Safely arrived at destination';
    } else {
      step5State = _TimelineStepState.upcoming;
      step5Sub = 'Final drop-off';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'BOOKING TIMELINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TimelineItem(
            title: 'Request Placed',
            subtitle: step1Sub,
            state: step1State,
            isFirst: true,
          ),
          _TimelineItem(
            title: 'Co-Rider Matching',
            subtitle: step2Sub,
            state: step2State,
          ),
          _TimelineItem(
            title: 'Driver & Fare Lock',
            subtitle: step3Sub,
            state: step3State,
          ),
          _TimelineItem(
            title: 'Trip En Route',
            subtitle: step4Sub,
            state: step4State,
          ),
          _TimelineItem(
            title: 'Arrived at Destination',
            subtitle: step5Sub,
            state: step5State,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.state,
    this.isFirst = false,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final _TimelineStepState state;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node icon and vertical connector
          Column(
            children: [
              _buildNodeIcon(),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: state == _TimelineStepState.completed
                        ? AppColors.primary
                        : AppColors.timelineTrack,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Text content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: state == _TimelineStepState.upcoming
                          ? FontWeight.w500
                          : FontWeight.w700,
                      color: state == _TimelineStepState.upcoming
                          ? AppColors.onSurfaceMuted
                          : AppColors.onBackground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(
                      color: state == _TimelineStepState.active
                          ? AppColors.primaryDark
                          : AppColors.onSurfaceMuted,
                      fontWeight: state == _TimelineStepState.active
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeIcon() {
    switch (state) {
      case _TimelineStepState.completed:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.onPrimary,
            size: 15,
          ),
        );
      case _TimelineStepState.active:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: AppShadows.soft,
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case _TimelineStepState.failed:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.errorTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            color: AppColors.error,
            size: 15,
          ),
        );
      case _TimelineStepState.upcoming:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.timelineTrack, width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.timelinePending,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting Sub-Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Animated pulsing dot for searching state.
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
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) {
      return Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.primaryTint,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.people_rounded,
            size: 32, color: AppColors.primary),
      );
    }
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.primaryTint,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.people_rounded,
            size: 32, color: AppColors.primary),
      ),
    );
  }
}

/// Animated rider counter.
class _AnimatedRiderCount extends StatelessWidget {
  const _AnimatedRiderCount({required this.count, this.style});
  final int count;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      transitionBuilder: (child, anim) {
        if (AppMotion.isReducedMotion(context)) return child;
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: Text(
        '$count',
        key: ValueKey(count),
        style: style,
      ),
    );
  }
}

/// Elevated card container with 20px radius and soft shadow (no hard border).
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children, this.title});
  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: tt.titleLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
          ],
          ...children,
        ],
      ),
    );
  }
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

/// Single rider row inside the co-riders card.
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
                  ? AppColors.primaryTint
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$pickupOrder',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelf ? AppColors.primaryDark : AppColors.onSurfaceMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelf ? FontWeight.w700 : FontWeight.w500,
                    color: isSelf
                        ? AppColors.onBackground
                        : AppColors.onSurfaceMuted,
                  ),
            ),
          ),
          Text(
            '৳${fare.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      );
}
