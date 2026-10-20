import 'package:go_router/go_router.dart';
import 'package:sharegari/features/auth/login_screen.dart';
import 'package:sharegari/features/home/home_screen.dart';
import 'package:sharegari/features/ride_request/ride_request_screen.dart';
import 'package:sharegari/features/my_rides/my_rides_screen.dart';

/// Named route constants — use these everywhere instead of raw strings.
abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const rideRequest = '/ride-request';
  static const myRides = '/my-rides';
}

/// Central GoRouter instance.
///
/// For now every route is accessible. Authentication guards will be
/// added in Step 3 once Supabase auth is wired up.
final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
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
