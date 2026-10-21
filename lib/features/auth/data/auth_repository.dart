import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sharegari/core/supabase/supabase_client_provider.dart';

/// Returned by every [AuthRepository] operation.
/// Never throws — callers check [isSuccess] / [error] instead.
class AuthResult {
  const AuthResult.success(User this.user) : error = null;
  const AuthResult.failure(String this.error) : user = null;

  final User? user;
  final String? error;

  bool get isSuccess => user != null;
}

/// Thin wrapper around [SupabaseClient] auth.
///
/// Using email login during development.
/// Phone OTP will replace this in a later step once an SMS provider is set up.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  // ── Accessors ────────────────────────────────────────────────────────

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  /// Stream of [AuthState] changes (SIGNED_IN, SIGNED_OUT, TOKEN_REFRESHED…).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Email auth ───────────────────────────────────────────────────────

  /// Sign up with email + password.
  ///
  /// Passes [name], [phone], and [role] as user metadata so the Postgres
  /// trigger (migration 002) can populate the public.users row immediately.
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    String role = 'rider',
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name.trim(),
          'phone': phone.trim(),
          'role': role,
        },
      );
      final user = res.user;
      if (user == null) {
        return const AuthResult.failure(
          'Sign-up succeeded but no user returned. '
          'Disable email confirmation in Supabase Auth settings for dev.',
        );
      }
      return AuthResult.success(user);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  /// Sign in with email + password.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) return const AuthResult.failure('Sign-in failed.');
      return AuthResult.success(user);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  /// Sign out the current user and clear local session.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

/// Riverpod provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
