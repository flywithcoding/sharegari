import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/core/location/geocoding_provider.dart';
import 'package:sharegari/core/location/location_model.dart';
import 'package:sharegari/core/theme/app_theme.dart';

/// Bottom sheet for searching locations via [GeocodingService].
///
/// Shows a search field at the top and a list of [LocationResult] below.
/// Tap a result to return it to the caller via [Navigator.pop].
///
/// Usage:
/// ```dart
/// final result = await showLocationSearchSheet(context, ref,
///     hint: 'Search pickup location');
/// if (result != null) { ... }
/// ```
Future<LocationResult?> showLocationSearchSheet(
  BuildContext context,
  WidgetRef ref, {
  required String hint,
}) {
  return showModalBottomSheet<LocationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _LocationSearchSheet(hint: hint),
    ),
  );
}

class _LocationSearchSheet extends ConsumerStatefulWidget {
  const _LocationSearchSheet({required this.hint});
  final String hint;

  @override
  ConsumerState<_LocationSearchSheet> createState() =>
      _LocationSearchSheetState();
}

class _LocationSearchSheetState
    extends ConsumerState<_LocationSearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  List<LocationResult> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query == _lastQuery) return;
    _lastQuery = query;
    setState(() => _loading = true);
    final results =
        await ref.read(geocodingServiceProvider).search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            // Handle bar
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: AppColors.primary),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Loading / results
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else if (_results.isEmpty && _ctrl.text.length >= 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text('No results found',
                    style: tt.bodySmall
                        ?.copyWith(color: AppColors.onSurfaceMuted)),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: _results.length,
                  separatorBuilder: (_, i) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      leading: const Icon(Icons.place_rounded,
                          color: AppColors.primary, size: 20),
                      title: Text(r.displayLabel,
                          style: tt.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: r.address != r.displayLabel
                          ? Text(r.address,
                              style: tt.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)
                          : null,
                      onTap: () => Navigator.pop(context, r),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
