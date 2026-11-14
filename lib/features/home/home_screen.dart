import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/core/widgets/pressable_scale.dart';
import 'package:sharegari/features/auth/data/auth_repository.dart';
import 'package:sharegari/features/auth/providers/auth_providers.dart';
import 'package:sharegari/features/profile/providers/profile_providers.dart';
import 'package:sharegari/features/ride_request/providers/ride_request_providers.dart';

/// Home / dashboard screen for riders with a modern, spacious card layout.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final myRidesAsync = ref.watch(myRidesProvider);

    final displayName = (profile?.fullName ?? '').isNotEmpty
        ? profile!.fullName.split(' ').first
        : user?.userMetadata?['name'] as String? ??
            user?.email?.split('@').first ??
            'there';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ShareGari',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'My Profile',
            onPressed: () => context.push(AppRoutes.profile),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              ref.invalidate(profileProvider);
              ref.invalidate(userRideStatsProvider);
              ref.invalidate(myRidesProvider);
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Greeting & Headline ────────────────────────────────────
              const SizedBox(height: 4),
              Text(
                'Hello, $displayName 👋',
                style: tt.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Where are you\ngoing today?',
                style: tt.headlineMedium?.copyWith(
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),

              // ── 2. Hero Quick-Request Card ────────────────────────────────
              _HeroBookingCard(
                onTap: () => context.push(AppRoutes.rideRequest),
              ),
              const SizedBox(height: 28),

              // ── 3. Recent Ride Card / Activity ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Activity',
                    style: tt.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.myRides),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('See all'),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              myRidesAsync.when(
                data: (rides) {
                  if (rides.isEmpty) {
                    return const _EmptyRecentCard();
                  }
                  final latest = rides.first;
                  return _ActiveRidePreviewCard(
                    ride: latest,
                    onTap: () => context.push(
                      AppRoutes.rideStatusPath(latest.id),
                      extra: <String, dynamic>{
                        'pickupAddress': latest.pickupAddress,
                        'dropAddress': latest.dropAddress,
                        'estimatedSoloFare': latest.estimatedSoloFare,
                        'estimatedShareFare': latest.estimatedShareFare,
                        'departAt': latest.departAt.toUtc().toIso8601String(),
                      },
                    ),
                  );
                },
                loading: () => const _LoadingRecentCard(),
                error: (err, stack) => const _EmptyRecentCard(),
              ),
              const SizedBox(height: 28),

              // ── 4. Value Proposition Cards ────────────────────────────────
              Text(
                'Why ShareGari',
                style: tt.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const _FeatureCardsGrid(),
              const SizedBox(height: 80), // spacing above navigation
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          elevation: 0,
          backgroundColor: AppColors.background,
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
              icon: Icon(Icons.confirmation_number_outlined),
              activeIcon: Icon(Icons.confirmation_number_rounded),
              label: 'My Rides',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
      floatingActionButton: PressableScale(
        child: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.rideRequest),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text(
            'Request Ride',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen Cards
// ─────────────────────────────────────────────────────────────────────────────

/// Hero card providing one-tap access to find a shared ride.
class _HeroBookingCard extends StatelessWidget {
  const _HeroBookingCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadii.cardLarge,
          boxShadow: AppShadows.elevated,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: AppRadii.pill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SAVE UP TO 75%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Visual Destination Input Mock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
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
                        height: 14,
                        color: AppColors.border,
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your location in Dhaka',
                          style: tt.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Where are you headed?',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onBackground,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: AppColors.onPrimary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Subtitle caption
            Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Carpool with verified commuters on your route',
                  style: tt.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Preview card for the most recent ride request.
class _ActiveRidePreviewCard extends StatelessWidget {
  const _ActiveRidePreviewCard({required this.ride, required this.onTap});
  final dynamic ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dateStr =
        DateFormat('EEE, d MMM · hh:mm a').format(ride.departAt as DateTime);

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: AppRadii.pill,
                  ),
                  child: Text(
                    'LATEST REQUEST',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: tt.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.trip_origin_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.pickupAddress as String,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 7),
              child: SizedBox(
                height: 10,
                child: VerticalDivider(color: AppColors.border, thickness: 1.5),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.dropAddress as String,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (ride.estimatedShareFare != null)
                  Text(
                    'Est. ৳${(ride.estimatedShareFare as double).toStringAsFixed(0)}',
                    style: tt.titleMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    Text(
                      'View details',
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback empty state for recent rides on home.
class _EmptyRecentCard extends StatelessWidget {
  const _EmptyRecentCard();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.card,
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active requests',
                  style: tt.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Plan ahead: schedule your ride up to 7 days in advance.',
                  style: tt.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingRecentCard extends StatelessWidget {
  const _LoadingRecentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.card,
      ),
    );
  }
}

/// 3 clean cards presenting how ShareGari works.
class _FeatureCardsGrid extends StatelessWidget {
  const _FeatureCardsGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _FeatureTile(
          icon: Icons.schedule_rounded,
          iconColor: AppColors.primary,
          title: 'Flexible time window',
          description:
              'Set a ±10 to ±20 minute departure window for maximum matching chances.',
        ),
        SizedBox(height: 10),
        _FeatureTile(
          icon: Icons.group_work_rounded,
          iconColor: AppColors.secondary,
          title: 'Smart route pooling',
          description:
              'Our engine bundles 2–4 riders traveling the same corridor with minimal detour.',
        ),
        SizedBox(height: 10),
        _FeatureTile(
          icon: Icons.payments_rounded,
          iconColor: AppColors.accent,
          title: 'Dynamic split fares',
          description:
              'Fares start low and drop further as more co-riders join your car.',
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.card,
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(24),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: tt.bodySmall?.copyWith(
                    height: 1.35,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
