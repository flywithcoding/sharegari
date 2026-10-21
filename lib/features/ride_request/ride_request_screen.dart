import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/core/location/location_model.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/features/ride_request/widgets/location_search_sheet.dart';
import 'package:sharegari/features/ride_request/widgets/map_picker.dart';

/// Ride request screen — full map picker + Barikoi search + time/flexibility.
///
/// Step 5 will save the composed request to Supabase.
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

  // ── Location search helpers ──────────────────────────────────────────

  Future<void> _searchPickup() async {
    final result = await showLocationSearchSheet(
      context,
      ref,
      hint: 'Search pickup location…',
    );
    if (result != null) setState(() => _pickup = result);
  }

  Future<void> _searchDropoff() async {
    final result = await showLocationSearchSheet(
      context,
      ref,
      hint: 'Search drop-off location…',
    );
    if (result != null) setState(() => _dropoff = result);
  }

  // ── Time picker ──────────────────────────────────────────────────────

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
    );
    if (picked != null) setState(() => _departureTime = picked);
  }

  // ── Submit ───────────────────────────────────────────────────────────

  bool get _canSubmit => _pickup != null && _dropoff != null;

  void _submit() {
    // Step 5 will send this to Supabase.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📍 ${_pickup!.displayLabel} → ${_dropoff!.displayLabel}\n'
          '🕐 ${_departureTime.format(context)} ±$_flexibilityMinutes min\n'
          '(Will save to Supabase in Step 5)',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Request a Shared Ride')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Map (takes top portion of screen) ─────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: MapPicker(
                  pickupLocation: _pickup,
                  dropoffLocation: _dropoff,
                  onPickup: (r) => setState(() => _pickup = r),
                  onDropoff: (r) => setState(() => _dropoff = r),
                ),
              ),
            ),

            // ── Form panel (bottom) ─────────────────────────────────
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Savings banner
                    _SavingsBanner(),
                    const SizedBox(height: 14),

                    // Pickup field
                    _LocationField(
                      label: 'Pickup',
                      icon: Icons.my_location_rounded,
                      iconColor: AppColors.primary,
                      value: _pickup?.displayLabel,
                      hint: 'Tap map or search…',
                      onTap: _searchPickup,
                    ),
                    const SizedBox(height: 10),

                    // Drop-off field
                    _LocationField(
                      label: 'Drop-off',
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.secondary,
                      value: _dropoff?.displayLabel,
                      hint: 'Tap map or search…',
                      onTap: _searchDropoff,
                    ),
                    const SizedBox(height: 14),

                    // Departure time + flexibility row
                    Row(
                      children: [
                        Expanded(
                          child: _TimePickerTile(
                            time: _departureTime,
                            onTap: _pickTime,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FlexChips(
                          value: _flexibilityMinutes,
                          onChanged: (v) =>
                              setState(() => _flexibilityMinutes = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: _canSubmit ? _submit : null,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Find Shared Ride'),
                    ),

                    if (!_canSubmit)
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
            color: value != null ? iconColor.withAlpha(120) : Colors.transparent,
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
                      fontWeight: value != null
                          ? FontWeight.w500
                          : FontWeight.normal,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
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
