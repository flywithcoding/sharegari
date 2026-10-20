import 'package:flutter/material.dart';
import 'package:sharegari/core/theme/app_theme.dart';

/// My Rides screen — shows upcoming and past shared rides.
///
/// Step 5 will connect this to Supabase to show real ride_request rows.
class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Rides')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status filter chips
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatusChip(label: 'All', isSelected: true),
                    const SizedBox(width: 8),
                    _StatusChip(label: 'Active'),
                    const SizedBox(width: 8),
                    _StatusChip(label: 'Completed'),
                    const SizedBox(width: 8),
                    _StatusChip(label: 'Cancelled'),
                  ],
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_car_outlined,
                          size: 64, color: AppColors.onSurfaceMuted),
                      const SizedBox(height: 16),
                      Text('No rides yet', style: tt.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        'Your active and past shared rides will appear here once you make a request.',
                        style: tt.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Rides will be loaded from Supabase in Step 5.',
                        style: tt.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.isSelected = false});
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            isSelected ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceMuted,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
    );
  }
}
