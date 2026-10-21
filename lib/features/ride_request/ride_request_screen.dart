import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sharegari/core/location/location_model.dart';
import 'package:sharegari/core/pricing/fare_calculator.dart';
import 'package:sharegari/core/pricing/fare_calculator_provider.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/routing/ors_routing_service.dart';
import 'package:sharegari/core/routing/routing_service.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/features/auth/providers/auth_providers.dart';
import 'package:sharegari/features/ride_request/data/ride_request_model.dart';
import 'package:sharegari/features/ride_request/data/ride_request_repository.dart';
import 'package:sharegari/features/ride_request/widgets/location_search_sheet.dart';
import 'package:sharegari/features/ride_request/widgets/map_picker.dart';

/// Ride request screen — map picker, Barikoi search, ORS fare estimate,
/// Supabase INSERT with estimated fares saved on the row.
class RideRequestScreen extends ConsumerStatefulWidget {
  const RideRequestScreen({super.key});

  @override
  ConsumerState<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends ConsumerState<RideRequestScreen> {
  LocationResult? _pickup;
  LocationResult? _dropoff;
  TimeOfDay _departureTime = TimeOfDay.now();
  int _flexibilityMinutes = 10;

  bool _submitting = false;
  String? _errorMessage;

  /// Cached route result — recomputed whenever both pins change.
  OrsRouteResult? _route;
  bool _fetchingRoute = false;

  // ── Location helpers ─────────────────────────────────────────────────

  Future<void> _searchPickup() async {
    final result = await showLocationSearchSheet(
      context,
      ref,
      hint: 'Search pickup location…',
    );
    if (result != null) {
      setState(() => _pickup = result);
      _refreshRoute();
    }
  }

  Future<void> _searchDropoff() async {
    final result = await showLocationSearchSheet(
      context,
      ref,
      hint: 'Search drop-off location…',
    );
    if (result != null) {
      setState(() => _dropoff = result);
      _refreshRoute();
    }
  }

  // ── Route + fare ─────────────────────────────────────────────────────

  /// Fetches a fresh route from ORS whenever both pins are set.
  Future<void> _refreshRoute() async {
    if (_pickup == null || _dropoff == null) return;
    setState(() {
      _fetchingRoute = true;
      _route = null;
    });
    final routing = ref.read(routingServiceProvider);
    final result = await routing.getRoute(_pickup!.latLng, _dropoff!.latLng);
    if (!mounted) return;
    setState(() {
      _route = result;
      _fetchingRoute = false;
    });
  }

  FareRange? get _fareRange {
    final r = _route;
    if (r == null) return null;
    return ref.read(fareCalculatorProvider).estimateRange(
          distanceKm: r.distanceKm,
          durationMin: r.durationMin,
        );
  }

  // ── Time picker ──────────────────────────────────────────────────────

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _departureTime);
    if (picked != null) setState(() => _departureTime = picked);
  }

  // ── Submit ───────────────────────────────────────────────────────────

  bool get _canSubmit =>
      _pickup != null && _dropoff != null && !_submitting && !_fetchingRoute;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    // Build departure DateTime from today + chosen time.
    final now = DateTime.now();
    var depart = DateTime(
        now.year, now.month, now.day, _departureTime.hour, _departureTime.minute);
    if (depart.isBefore(now)) depart = depart.add(const Duration(days: 1));

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Not signed in. Please restart the app.';
      });
      return;
    }

    // Fetch route if we don't have one yet (e.g. ORS wasn't tried).
    OrsRouteResult? route = _route;
    if (route == null && _pickup != null && _dropoff != null) {
      route = await ref
          .read(routingServiceProvider)
          .getRoute(_pickup!.latLng, _dropoff!.latLng);
    }

    // Compute fare estimates from the route (null if ORS unavailable).
    final calc = ref.read(fareCalculatorProvider);
    double? soloFare;
    double? shareFare4;
    if (route != null) {
      soloFare = calc.riderFare(
          distanceKm: route.distanceKm,
          durationMin: route.durationMin,
          groupSize: 1);
      shareFare4 = calc.riderFare(
          distanceKm: route.distanceKm,
          durationMin: route.durationMin,
          groupSize: 4);
    }

    final request = RideRequest(
      id: '',
      riderId: userId,
      pickupLatLng: _pickup!.latLng,
      pickupAddress: _pickup!.address,
      dropLatLng: _dropoff!.latLng,
      dropAddress: _dropoff!.address,
      departAt: depart,
      windowMin: _flexibilityMinutes,
      status: RideRequestStatus.searching,
      estimatedSoloFare: soloFare,
      estimatedShareFare: shareFare4,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(rideRequestRepositoryProvider).insert(request);
      if (!mounted) return;
      context.go(AppRoutes.myRides);
    } on PostgrestException catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final fareRange = _fareRange;

    return Scaffold(
      appBar: AppBar(title: const Text('Request a Shared Ride')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Map (top 55%) ────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: MapPicker(
                  pickupLocation: _pickup,
                  dropoffLocation: _dropoff,
                  onPickup: (r) {
                    setState(() => _pickup = r);
                    _refreshRoute();
                  },
                  onDropoff: (r) {
                    setState(() => _dropoff = r);
                    _refreshRoute();
                  },
                ),
              ),
            ),

            // ── Form panel (bottom 45%) ──────────────────────────────
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fare estimate banner (replaces generic savings banner
                    // once we have a route).
                    if (fareRange != null)
                      _FareBanner(range: fareRange)
                    else if (_fetchingRoute)
                      const _RouteLoadingBanner()
                    else
                      _SavingsBanner(),

                    const SizedBox(height: 12),

                    // Route info chip (distance + duration)
                    if (_route != null)
                      _RouteInfoChip(route: _route!)
                    else
                      const SizedBox.shrink(),

                    if (_route != null) const SizedBox(height: 8),

                    // Pickup field
                    _LocationField(
                      label: 'Pickup',
                      icon: Icons.my_location_rounded,
                      iconColor: AppColors.primary,
                      value: _pickup?.displayLabel,
                      hint: 'Tap map or search…',
                      onTap: _searchPickup,
                    ),
                    const SizedBox(height: 8),

                    // Drop-off field
                    _LocationField(
                      label: 'Drop-off',
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.secondary,
                      value: _dropoff?.displayLabel,
                      hint: 'Tap map or search…',
                      onTap: _searchDropoff,
                    ),
                    const SizedBox(height: 12),

                    // Time + flexibility row
                    Row(
                      children: [
                        Expanded(
                          child: _TimePickerTile(
                            time: _departureTime,
                            onTap: _pickTime,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FlexChips(
                          value: _flexibilityMinutes,
                          onChanged: (v) =>
                              setState(() => _flexibilityMinutes = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Error banner
                    if (_errorMessage != null) ...[
                      _ErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 10),
                    ],

                    ElevatedButton.icon(
                      onPressed: _canSubmit ? _submit : null,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.onPrimary),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(
                          _submitting ? 'Submitting…' : 'Find Shared Ride'),
                    ),

                    if (!_canSubmit && !_submitting && !_fetchingRoute)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Tap the map or search to set pickup & drop-off.',
                          style: tt.bodySmall
                              ?.copyWith(color: AppColors.onSurfaceMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

/// Shows once the route distance + fare range are known.
class _FareBanner extends StatelessWidget {
  const _FareBanner({required this.range});
  final FareRange range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_rounded,
              color: AppColors.onPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Est. shared fare per person',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onPrimary.withAlpha(200)),
                ),
                Text(
                  range.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  'Range: 4-person (best) to 2-person',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onPrimary.withAlpha(180),
                      fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLoadingBanner extends StatelessWidget {
  const _RouteLoadingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text('Calculating route & fare…',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
        ],
      ),
    );
  }
}

class _RouteInfoChip extends StatelessWidget {
  const _RouteInfoChip({required this.route});
  final OrsRouteResult route;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.straighten_rounded,
            size: 14, color: AppColors.onSurfaceMuted),
        const SizedBox(width: 4),
        Text(
          '${route.distanceKm.toStringAsFixed(1)} km  ·  '
          '${route.durationMin.toStringAsFixed(0)} min',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _SavingsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_rounded,
              color: AppColors.onPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Save up to 75% — as low as ৳125 per person!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.hint,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color iconColor;
  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                value != null ? iconColor.withAlpha(120) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.onSurfaceMuted)),
                  const SizedBox(height: 2),
                  Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: 13,
                      color: value != null
                          ? AppColors.onSurface
                          : AppColors.onSurfaceMuted,
                      fontWeight:
                          value != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.search_rounded,
                size: 16, color: AppColors.onSurfaceMuted),
          ],
        ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({required this.time, required this.onTap});
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(time.format(context),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _FlexChips extends StatelessWidget {
  const _FlexChips({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [10, 15, 20].map((m) {
        final selected = value == m;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => onChanged(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color:
                    selected ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '±$m',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceMuted,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withAlpha(100)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
