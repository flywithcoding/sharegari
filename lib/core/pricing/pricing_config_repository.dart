import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/core/pricing/pricing_config.dart';
import 'package:sharegari/core/supabase/supabase_client_provider.dart';

/// Fetches the singleton `pricing_config` row from Supabase.
///
/// Uses [AsyncNotifier] so the app can react when the admin updates config.
/// Falls back to [PricingConfig.fallback] on network errors.
class PricingConfigNotifier extends AsyncNotifier<PricingConfig> {
  @override
  Future<PricingConfig> build() => _fetch();

  Future<PricingConfig> _fetch() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final row = await client
          .from('pricing_config')
          .select()
          .eq('id', 1)
          .single();
      return PricingConfig.fromJson(row);
    } catch (_) {
      return PricingConfig.fallback;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final pricingConfigProvider =
    AsyncNotifierProvider<PricingConfigNotifier, PricingConfig>(
  PricingConfigNotifier.new,
);

/// Convenience synchronous provider.
///
/// Returns [PricingConfig.fallback] while the async fetch is in-flight or
/// has errored, so callers never receive null.
final pricingConfigSyncProvider = Provider<PricingConfig>((ref) {
  return ref
      .watch(pricingConfigProvider)
      .maybeWhen(data: (c) => c, orElse: () => PricingConfig.fallback);
});
