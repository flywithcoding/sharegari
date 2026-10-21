import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sharegari/features/auth/login_screen.dart';
import 'package:sharegari/features/auth/register_screen.dart';
import 'package:sharegari/features/auth/providers/auth_providers.dart';
import 'package:sharegari/features/home/home_screen.dart';
import 'package:sharegari/features/ride_request/ride_request_screen.dart';
import 'package:sharegari/features/my_rides/my_rides_screen.dart';
import 'package:sharegari/features/ride_status/ride_status_screen.dart';

/// Named route path constants.
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/';
  static const rideRequest = '/ride-request';
  static const myRides = '/my-rides';

  /// Path: /ride-status/:requestId
  /// Extra keys: 'pickupAddress', 'dropAddress',
  ///             'estimatedSoloFare', 'estimatedShareFare', 'departAt' (ISO string)
  static const rideStatus = '/ride-status/:requestId';

  static String rideStatusPath(String requestId) =>
      '/ride-status/$requestId';
}

/// Routes that do not require authentication.
const _publicRoutes = {AppRoutes.login, AppRoutes.register};

/// Creates the auth-guarded [GoRouter].
///
/// ## How auth-reactive routing works
///
/// 1. [_AuthChangeNotifier] listens to [authUserProvider] and calls
///    [notifyListeners()] on every emission (SIGNED_IN, SIGNED_OUT, …).
/// 2. GoRouter's [refreshListenable] calls [redirect] after every notification.
/// 3. [redirect] reads [authUserProvider] with `ref.read` to get the latest
///    cached [AsyncValue<User?>].
///    - `isLoading` (first frame, stream not yet emitted): stay put — the notifier
///      will fire again once the stream emits, so the router will re-evaluate.
///    - `hasValue`: use `value` (may be null = signed out).
///    - `hasError`: treat as signed-out and send to /login.
///
/// ## Why `authUserProvider` instead of `currentUserProvider`
///
/// The old `currentUserProvider` was a plain `Provider<User?>` that called
/// `_client.auth.currentUser` synchronously. On Android this getter returns
/// the session loaded from disk, but the result is not reactive — the router
/// never got notified of sign-in/sign-out and the redirect always read the
/// stale startup value. `authUserProvider` is a `StreamProvider` that maps
/// `onAuthStateChange`, so every change propagates automatically.
GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final userAsync = ref.read(authUserProvider);

      // Stream not yet emitted (cold start). Stay put — the notifier will
      // fire once the session is resolved and the router re-evaluates.
      if (userAsync.isLoading) return null;

      // Treat errors like signed-out.
      final isSignedIn =
          !userAsync.hasError && (userAsync.valueOrNull != null);
      final isPublic = _publicRoutes.contains(state.matchedLocation);

      // Not signed in → /login
      if (!isSignedIn && !isPublic) return AppRoutes.login;

      // Already signed in → skip login/register, go home
      if (isSignedIn && isPublic) return AppRoutes.home;

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.rideRequest,
        name: 'rideRequest',
        builder: (context, state) => const RideRequestScreen(),
      ),
      GoRoute(
        path: AppRoutes.myRides,
        name: 'myRides',
        builder: (context, state) => const MyRidesScreen(),
      ),
      GoRoute(
        path: AppRoutes.rideStatus,
        name: 'rideStatus',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final departStr = extra['departAt'] as String?;
          return RideStatusScreen(
            requestId:          requestId,
            pickupAddress:      extra['pickupAddress'] as String?,
            dropAddress:        extra['dropAddress'] as String?,
            estimatedSoloFare:  extra['estimatedSoloFare'] as double?,
            estimatedShareFare: extra['estimatedShareFare'] as double?,
            departAt: departStr != null ? DateTime.parse(departStr) : null,
          );
        },
      ),
    ],
  );
}

/// [Listenable] that notifies GoRouter whenever the Supabase auth state changes.
///
/// GoRouter's [refreshListenable] triggers a re-evaluation of [redirect]
/// each time [notifyListeners()] fires.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(WidgetRef ref) {
    // Watch the USER stream (not the raw AuthState stream).
    // Every emission — including SIGNED_IN on Android — triggers the router.
    ref.listen(authUserProvider, (prev, next) => notifyListeners());
  }
}
