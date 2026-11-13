import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/features/auth/providers/auth_providers.dart';
import 'package:sharegari/features/profile/data/profile_models.dart';
import 'package:sharegari/features/profile/data/profile_repository.dart';

/// Provider for the current user's profile.
/// Refreshed whenever the profile is updated or user logs in.
final profileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).fetchProfile(user.id);
});

/// Provider for the user's ride stats.
final userRideStatsProvider = FutureProvider.autoDispose<UserRideStats>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return UserRideStats.zero;
  return ref.watch(profileRepositoryProvider).fetchRideStats(user.id);
});
