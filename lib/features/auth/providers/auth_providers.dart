import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sharegari/features/auth/data/auth_repository.dart';

/// Streams live [AuthState] changes (SIGNED_IN, SIGNED_OUT, etc.).
/// The GoRouter redirect function listens to this to guard protected routes.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// Synchronous snapshot of the currently signed-in [User].
/// Returns null when the user is signed out.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authRepositoryProvider).currentUser,
);
