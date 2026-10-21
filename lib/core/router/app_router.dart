import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sharegari/features/auth/login_screen.dart';
import 'package:sharegari/features/auth/register_screen.dart';
import 'package:sharegari/features/auth/providers/auth_providers.dart';
import 'package:sharegari/features/home/home_screen.dart';
import 'package:sharegari/features/ride_request/ride_request_screen.dart';
import 'package:sharegari/features/my_rides/my_rides_screen.dart';

/// Named route path constants.
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/';
  static const rideRequest = '/ride-request';
  static const myRides = '/my-rides';
}

/// Routes that do not require authentication.
const _publicRoutes = {AppRoutes.login, AppRoutes.register};

/// Creates the auth-guarded [GoRouter].
///
/// Takes a [ProviderContainer] (or [WidgetRef]) so it can watch
/// [authStateProvider] and redirect unauthenticated users to /login.
GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final authValue = ref.read(authStateProvider);
      // While the auth stream is loading, stay put.
      if (authValue.isLoading) return null;

      final isSignedIn = ref.read(currentUserProvider) != null;
      final isPublic = _publicRoutes.contains(state.matchedLocation);

      // Not signed in and trying to access a protected route → /login
      if (!isSignedIn && !isPublic) return AppRoutes.login;

      // Already signed in and trying to visit login/register → home
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
    ],
  );
}

/// [Listenable] that notifies GoRouter whenever the Supabase auth state changes.
///
/// GoRouter's [refreshListenable] triggers a re-evaluation of [redirect]
/// each time this fires, keeping the navigation in sync with auth state.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(WidgetRef ref) {
    // Watch the auth stream and notify the router on every change.
    ref.listen(authStateProvider, (_, next) => notifyListeners());
  }
}
