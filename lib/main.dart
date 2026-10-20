import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/core/env.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_theme.dart';

/// Entry point.
///
/// Run with:
///   flutter run --dart-define-from-file=env.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast in debug builds if any env var is missing.
  AppEnv.assertAll();

  // TODO(step-3): Initialise Supabase here once auth is wired.
  // await Supabase.initialize(
  //   url: AppEnv.supabaseUrl,
  //   anonKey: AppEnv.supabaseAnonKey,
  // );

  runApp(
    // ProviderScope is the Riverpod root — required for all providers.
    const ProviderScope(
      child: ShareGariApp(),
    ),
  );
}

class ShareGariApp extends StatelessWidget {
  const ShareGariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ShareGari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
