import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the singleton [SupabaseClient] initialised in [main].
///
/// All repositories depend on this instead of calling
/// `Supabase.instance.client` directly, making them unit-testable
/// via provider overrides.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
