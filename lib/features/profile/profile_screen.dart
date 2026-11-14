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

/// User Profile screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out of ShareGari?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 1. Invalidate user-bound providers so next session starts completely clean
    ref.invalidate(profileProvider);
    ref.invalidate(userRideStatsProvider);
    ref.invalidate(myRidesProvider);

    // 2. Sign out of Supabase (terminates sessions and realtime channels)
    await ref.read(authRepositoryProvider).signOut();

    // 3. Router redirect automatically routes to Login, but explicitly ensure:
    if (context.mounted) {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Account deletion requires data verification and driver/payment settlement.\n\n'
          'Contact support to delete your account:\nsupport@sharegari.com',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final authUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileProvider);
    final statsAsync = ref.watch(userRideStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => _goBack(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => context.push(AppRoutes.editProfile),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(userRideStatsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header: Avatar, Name, Email, Rating ─────────────────────
                Center(
                  child: profileAsync.when(
                    data: (profile) {
                      final name = profile?.fullName ??
                          authUser?.userMetadata?['name'] as String? ??
                          'User';
                      final phone = profile?.phone ??
                          authUser?.userMetadata?['phone'] as String? ??
                          'No phone set';
                      final email = authUser?.email ?? 'No email';
                      final rating = profile?.rating ?? 5.0;
                      final avatarUrl = profile?.avatarUrl;
                      final memberSince = profile?.createdAt ??
                          DateTime.tryParse(authUser?.createdAt ?? '') ??
                          DateTime.now();

                      return Column(
                        children: [
                          _AvatarView(
                            avatarUrl: avatarUrl,
                            initials: profile?.initials ?? 'U',
                            size: 88,
                          ),
                          const SizedBox(height: 14),
                          Text(name, style: tt.headlineSmall),
                          const SizedBox(height: 4),
                          Text(email, style: tt.bodySmall),
                          const SizedBox(height: 2),
                          Text(phone,
                              style: tt.bodySmall?.copyWith(
                                color: AppColors.onSurfaceMuted,
                              )),
                          const SizedBox(height: 10),
                          // Rating & Member since badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 16, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: tt.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  'Member since ${DateFormat('MMM yyyy').format(memberSince)}',
                                  style: tt.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Could not load profile: $e',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Ride statistics card ─────────────────────────────────────
                Text('Ride Activity', style: tt.titleMedium),
                const SizedBox(height: 10),
                statsAsync.when(
                  data: (stats) => Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Requests',
                          value: '${stats.totalRequests}',
                          icon: Icons.list_alt_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'Completed',
                          value: '${stats.completedRides}',
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'Cancelled',
                          value: '${stats.cancelledRides}',
                          icon: Icons.cancel_outlined,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (err, stack) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 28),

                // ── Action Buttons ──────────────────────────────────────────
                PressableScale(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.editProfile),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                PressableScale(
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.myRides),
                      icon: const Icon(Icons.directions_car_rounded, size: 18),
                      label: const Text('My Rides'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                PressableScale(
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      onPressed: () => _handleLogout(context, ref),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Logout'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () => _handleDeleteAccount(context),
                    child: Text(
                      'Delete Account',
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarView extends StatelessWidget {
  const _AvatarView({
    required this.avatarUrl,
    required this.initials,
    this.size = 80,
  });

  final String? avatarUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _initialsFallback(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            );
          },
        ),
      );
    }
    return _initialsFallback();
  }

  Widget _initialsFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              fontSize: 11,
              color: AppColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
