import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sharegari/core/env.dart';
import 'package:sharegari/core/location/geocoding_provider.dart';
import 'package:sharegari/core/location/location_model.dart';
import 'package:sharegari/core/theme/app_theme.dart';

/// Interactive flutter_map picker for pickup and drop-off.
///
/// • Tapping the map places / moves the active pin.
/// • After placing a pin the widget automatically reverse-geocodes
///   the coordinate via [GeocodingService] and calls [onPickup] /
///   [onDropoff] with the resolved [LocationResult].
/// • Tile provider: MapTiler (free tier) if key is available,
///   OpenStreetMap raster tiles otherwise.
class MapPicker extends ConsumerStatefulWidget {
  const MapPicker({
    super.key,
    this.initialCenter = const LatLng(23.8103, 90.4125), // Dhaka centre
    this.initialZoom = 13.0,
    this.pickupLocation,
    this.dropoffLocation,
    required this.onPickup,
    required this.onDropoff,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final LocationResult? pickupLocation;
  final LocationResult? dropoffLocation;
  final ValueChanged<LocationResult> onPickup;
  final ValueChanged<LocationResult> onDropoff;

  @override
  ConsumerState<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends ConsumerState<MapPicker> {
  late final MapController _mapController;

  /// Which pin the next tap will place: true = pickup, false = drop-off.
  bool _placingPickup = true;

  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String get _tileUrl {
    final key = AppEnv.mapTilerApiKey;
    if (key.isNotEmpty) {
      // MapTiler Streets (free tier — 100k tiles/month)
      return 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$key';
    }
    // Pure OpenStreetMap fallback (no key required)
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  Future<void> _onTap(TapPosition tapPos, LatLng latLng) async {
    if (_resolving) return;
    setState(() => _resolving = true);

    final service = ref.read(geocodingServiceProvider);
    LocationResult result = LocationResult(
      latLng: latLng,
      address: '${latLng.latitude.toStringAsFixed(5)}, '
          '${latLng.longitude.toStringAsFixed(5)}',
    );

    final resolved = await service.reverseGeocode(latLng);
    if (resolved != null) result = resolved;

    if (!mounted) return;
    setState(() => _resolving = false);

    if (_placingPickup) {
      widget.onPickup(result);
    } else {
      widget.onDropoff(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickupLocation;
    final dropoff = widget.dropoffLocation;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // ── The map ──────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: pickup?.latLng ??
                  dropoff?.latLng ??
                  widget.initialCenter,
              initialZoom: widget.initialZoom,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.sharegari.app',
                maxZoom: 19,
              ),
              // Pickup marker (green)
              if (pickup != null)
                MarkerLayer(markers: [
                  _buildMarker(
                    pickup.latLng,
                    Icons.my_location_rounded,
                    AppColors.primary,
                  ),
                ]),
              // Drop-off marker (orange)
              if (dropoff != null)
                MarkerLayer(markers: [
                  _buildMarker(
                    dropoff.latLng,
                    Icons.location_on_rounded,
                    AppColors.secondary,
                  ),
                ]),
              // Route line when both are set
              if (pickup != null && dropoff != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: [pickup.latLng, dropoff.latLng],
                    color: AppColors.primary.withAlpha(180),
                    strokeWidth: 3,
                    pattern: const StrokePattern.dotted(),
                  ),
                ]),
            ],
          ),

          // ── Tap mode toggle (top-left) ──────────────────────────────
          Positioned(
            top: 10,
            left: 10,
            child: _ModeToggle(
              placingPickup: _placingPickup,
              onChanged: (v) => setState(() => _placingPickup = v),
            ),
          ),

          // ── Resolving indicator ─────────────────────────────────────
          if (_resolving)
            const Positioned(
              top: 10,
              right: 10,
              child: _LoadingChip(),
            ),

          // ── Attribution ─────────────────────────────────────────────
          const Positioned(
            bottom: 4,
            right: 6,
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 9, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  static Marker _buildMarker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Icon(icon, color: color, size: 36,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black38)]),
    );
  }
}

// ── Mode toggle chip ─────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  const _ModeToggle(
      {required this.placingPickup, required this.onChanged});
  final bool placingPickup;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(230),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(
            label: 'Pickup',
            color: AppColors.primary,
            selected: placingPickup,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: 4),
          _Chip(
            label: 'Drop-off',
            color: AppColors.secondary,
            selected: !placingPickup,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppColors.primary),
          ),
          SizedBox(width: 6),
          Text('Resolving…',
              style: TextStyle(fontSize: 10, color: AppColors.onSurfaceMuted)),
        ],
      ),
    );
  }
}
