import 'package:flutter/material.dart';
import 'package:sharegari/core/theme/app_theme.dart';

/// Ride request screen — lets a rider choose pickup, drop-off, time, and flexibility.
///
/// Step 4 will add an interactive flutter_map picker.
/// Step 5 will save the request to Supabase.
class RideRequestScreen extends StatefulWidget {
  const RideRequestScreen({super.key});

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  TimeOfDay _departureTime = TimeOfDay.now();
  int _flexibilityMinutes = 10;

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
    );
    if (picked != null) {
      setState(() => _departureTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Request a Shared Ride')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Estimated savings banner
              _SavingsBanner(),
              const SizedBox(height: 24),

              Text('Pickup location', style: tt.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _pickupController,
                decoration: const InputDecoration(
                  hintText: 'Search or tap map to pin',
                  prefixIcon: Icon(Icons.my_location_rounded,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),

              Text('Drop-off location', style: tt.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _dropoffController,
                decoration: const InputDecoration(
                  hintText: 'Search or tap map to pin',
                  prefixIcon: Icon(Icons.location_on_rounded,
                      color: AppColors.secondary),
                ),
              ),
              const SizedBox(height: 24),

              // Map placeholder (Step 4 will replace this)
              _MapPlaceholder(),
              const SizedBox(height: 24),

              Text('Departure time', style: tt.titleMedium),
              const SizedBox(height: 8),
              _TimePicker(
                time: _departureTime,
                onTap: _pickTime,
              ),
              const SizedBox(height: 16),

              Text('Time flexibility', style: tt.titleMedium),
              const SizedBox(height: 4),
              Text(
                'How flexible is your departure? (±$_flexibilityMinutes min)',
                style: tt.bodySmall,
              ),
              Slider(
                value: _flexibilityMinutes.toDouble(),
                min: 10,
                max: 20,
                divisions: 2,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.surfaceVariant,
                label: '±$_flexibilityMinutes min',
                onChanged: (v) =>
                    setState(() => _flexibilityMinutes = v.round()),
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Ride saved! (Supabase integration in Step 5)'),
                    ),
                  );
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text('Find Shared Ride'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_rounded, color: AppColors.onPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Save up to 75% by sharing — as low as ৳125 per person!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _MapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_rounded, size: 48, color: AppColors.onSurfaceMuted),
            SizedBox(height: 8),
            Text(
              'Map picker — coming in Step 4\n(flutter_map + OpenStreetMap)',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({required this.time, required this.onTap});
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              time.format(context),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            const Icon(Icons.edit_rounded,
                size: 16, color: AppColors.onSurfaceMuted),
          ],
        ),
      ),
    );
  }
}
