/// Central access point for all environment variables injected via
/// `--dart-define-from-file=env.json`.
///
/// Usage:
///   flutter run --dart-define-from-file=env.json
///   flutter build apk --dart-define-from-file=env.json
///
/// Never hardcode values here — always provide them through env.json.
class AppEnv {
  AppEnv._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const orsApiKey = String.fromEnvironment('ORS_API_KEY');
  static const barikoiApiKey = String.fromEnvironment('BARIKOI_API_KEY');
  static const mapTilerApiKey = String.fromEnvironment('MAPTILER_API_KEY');

  /// Call once at startup to assert all required vars are present.
  static void assertAll() {
    assert(supabaseUrl.isNotEmpty,
        'SUPABASE_URL is missing. Run with --dart-define-from-file=env.json');
    assert(supabaseAnonKey.isNotEmpty,
        'SUPABASE_ANON_KEY is missing. Run with --dart-define-from-file=env.json');
    assert(orsApiKey.isNotEmpty,
        'ORS_API_KEY is missing. Run with --dart-define-from-file=env.json');
    assert(barikoiApiKey.isNotEmpty,
        'BARIKOI_API_KEY is missing. Run with --dart-define-from-file=env.json');
    assert(mapTilerApiKey.isNotEmpty,
        'MAPTILER_API_KEY is missing. Run with --dart-define-from-file=env.json');
  }
}
