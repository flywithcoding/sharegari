import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/features/auth/data/auth_repository.dart';
import 'package:sharegari/features/auth/providers/auth_providers.dart';
import 'package:sharegari/features/profile/providers/profile_providers.dart';

/// Home / dashboard screen for riders.
///
/// Now a [ConsumerWidget] so it can read auth state and trigger sign-out.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final displayName = profile?.fullName ??
        user?.userMetadata?['name'] as String? ??
        user?.email?.split('@').first ??
        'there';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShareGari'),
        actions: [
          // Profile avatar/icon button
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'My Profile',
            onPressed: () => context.push(AppRoutes.profile),
          ),
          // Sign-out button
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              ref.invalidate(profileProvider);
              ref.invalidate(userRideStatsProvider);
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting
              Text('Hello, $displayName 👋', style: tt.bodySmall),
              const SizedBox(height: 4),
              Text('Where are you going?', style: tt.headlineSmall),
              const SizedBox(height: 24),

              // Quick-request card
              _QuickRequestCard(
                onTap: () => context.push(AppRoutes.rideRequest),
              ),
              const SizedBox(height: 20),

              // Section: recent / active rides
              Row(
                children: [
                  Expanded(child: Text('My Rides', style: tt.titleMedium)),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.myRides),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _EmptyRidesPlaceholder(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) context.push(AppRoutes.myRides);
          if (i == 2) context.push(AppRoutes.profile);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_rounded),
            label: 'My Rides',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.rideRequest),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Request Ride'),
      ),
    );
  }
}

class _QuickRequestCard extends StatelessWidget {
  const _QuickRequestCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share a Ride',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Save up to 75% on your commute',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColors.onSurfaceMuted),
          ],
        ),
      ),
    );
  }
}

class _EmptyRidesPlaceholder extends StatelessWidget {
  const _EmptyRidesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.directions_car_outlined,
              size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text(
            'No rides yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your upcoming and past rides will appear here.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
