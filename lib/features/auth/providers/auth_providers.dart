import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sharegari/features/auth/data/auth_repository.dart';

// ── Auth stream provider ─────────────────────────────────────────────────────
//
// Streams the raw [AuthState] for anything that needs the full event
// (e.g. event type: SIGNED_IN, SIGNED_OUT, TOKEN_REFRESHED…).
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

// ── Current user (reactive) ──────────────────────────────────────────────────
//
// Maps the auth state stream directly to the current [User?].
//
// KEY FIX: This is a StreamProvider, not a plain Provider. GoRouter's
// refreshListenable calls redirect() after every emission, and this provider
// gives the router an up-to-date User? on every re-evaluation — even on
// Android where the stream only emits asynchronously.
//
// The router's redirect() reads this with ref.read() which gives the cached
// AsyncValue; when the stream emits the router is refreshed and re-reads it.
final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges.map(
        (authState) => authState.session?.user,
      ),
);

// ── Current user snapshot (backward-compat) ──────────────────────────────────
//
// Synchronous snapshot of the currently signed-in [User].
// Returns null when signed out or when the stream hasn't emitted yet.
//
// Other features (ride_request_screen, home_screen) read this.
// The router uses [authUserProvider] directly for reactive redirects.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authUserProvider).valueOrNull,
);
