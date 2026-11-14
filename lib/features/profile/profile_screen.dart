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

/// User Profile screen featuring a prominent large avatar header,
/// stat cards with soft shadows, and clean grouped settings cards.
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

    ref.invalidate(profileProvider);
    ref.invalidate(userRideStatsProvider);
    ref.invalidate(myRidesProvider);

    await ref.read(authRepositoryProvider).signOut();

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
    final tt = Theme.of(context).textTheme;
    final authUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileProvider);
    final statsAsync = ref.watch(userRideStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                // ── Large Avatar Header ──────────────────────────────────────
                profileAsync.when(
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
                        const SizedBox(height: 8),
                        // Large Avatar with soft shadow and edit badge
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            _LargeAvatarView(
                              avatarUrl: avatarUrl,
                              initials: profile?.initials ?? 'U',
                              size: 104,
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: PressableScale(
                                onTap: () => context.push(AppRoutes.editProfile),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.background, width: 2.5),
                                    boxShadow: AppShadows.soft,
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 15,
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // User Name
                        Text(
                          name,
                          style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),

                        // Contact info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.email_outlined,
                                size: 14, color: AppColors.onSurfaceMuted),
                            const SizedBox(width: 5),
                            Text(
                              email,
                              style: tt.bodySmall?.copyWith(
                                color: AppColors.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                        if (phone != 'No phone set') ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone_outlined,
                                  size: 14, color: AppColors.onSurfaceMuted),
                              const SizedBox(width: 5),
                              Text(
                                phone,
                                style: tt.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Rating & Member since floating pills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: AppRadii.pill,
                                boxShadow: AppShadows.soft,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 16, color: AppColors.accent),
                                  const SizedBox(width: 5),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: tt.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: AppRadii.pill,
                                boxShadow: AppShadows.soft,
                              ),
                              child: Text(
                                'Member since ${DateFormat('MMM yyyy').format(memberSince)}',
                                style: tt.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceMuted,
                                  fontWeight: FontWeight.w500,
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
                        style: const TextStyle(color: AppColors.error)),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Ride Activity Cards ──────────────────────────────────────
                Text(
                  'Ride Activity',
                  style: tt.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                statsAsync.when(
                  data: (stats) => Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Requests',
                          value: '${stats.totalRequests}',
                          icon: Icons.list_alt_rounded,
                          iconColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Completed',
                          value: '${stats.completedRides}',
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Cancelled',
                          value: '${stats.cancelledRides}',
                          icon: Icons.cancel_outlined,
                          iconColor: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (err, stack) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 28),

                // ── Grouped Settings Card ────────────────────────────────────
                Text(
                  'Account & Activity',
                  style: tt.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadii.card,
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    children: [
                      _ProfileMenuTile(
                        icon: Icons.person_outline_rounded,
                        iconColor: AppColors.primary,
                        title: 'Edit Profile',
                        subtitle: 'Change name, phone and avatar photo',
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                      const Divider(height: 1, indent: 64),
                      _ProfileMenuTile(
                        icon: Icons.confirmation_number_outlined,
                        iconColor: AppColors.secondary,
                        title: 'My Rides',
                        subtitle: 'View scheduled commutes and tickets',
                        onTap: () => context.push(AppRoutes.myRides),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Logout & Delete Account ──────────────────────────────────
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting Sub-Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _LargeAvatarView extends StatelessWidget {
  const _LargeAvatarView({
    required this.avatarUrl,
    required this.initials,
    this.size = 104,
  });

  final String? avatarUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppShadows.elevated,
          border: Border.all(color: AppColors.background, width: 3),
        ),
        child: ClipRRect(
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
        boxShadow: AppShadows.elevated,
        border: Border.all(color: AppColors.background, width: 3),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
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
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.card,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              fontSize: 12,
              color: AppColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
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
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
