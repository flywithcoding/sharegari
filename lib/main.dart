import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sharegari/core/env.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_theme.dart';

/// Entry point.
///
/// Run with:
///   flutter run --dart-define-from-file=env.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast in debug builds when Supabase keys are missing.
  assert(AppEnv.supabaseUrl.isNotEmpty,
      'SUPABASE_URL missing — run with --dart-define-from-file=env.json');
  assert(AppEnv.supabaseAnonKey.isNotEmpty,
      'SUPABASE_ANON_KEY missing — run with --dart-define-from-file=env.json');

  // Initialise Supabase. Must complete before runApp so auth state is ready.
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey, // ignore: deprecated_member_use
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  runApp(
    // ProviderScope is the Riverpod root — required for all providers.
    const ProviderScope(child: ShareGariApp()),
  );
}

/// Root widget. Uses [ConsumerWidget] so it can pass [WidgetRef]
/// to [createRouter] for the auth-guard redirect logic.
class ShareGariApp extends ConsumerWidget {
  const ShareGariApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // createRouter is called once here; GoRouter holds the instance.
    final router = createRouter(ref);

    return MaterialApp.router(
      title: 'ShareGari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
