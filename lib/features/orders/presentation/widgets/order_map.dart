import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// OpenStreetMap view for order tracking: the store, the customer's delivery
/// pin and — while the order is out for delivery — the driver, with the route
/// between them (solid where the driver has been, dotted where they're going).
///
/// The camera frames everything on screen and follows the driver as they move,
/// until the customer pans or zooms; a recenter button then brings back the
/// automatic framing.
class OrderMap extends StatefulWidget {
  const OrderMap({
    super.key,
    required this.store,
    this.home,
    this.driver,
    this.driverStale = false,
    this.driverAssumed = false,
    this.tileProvider,
    this.borderRadius = 16,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final LatLng store;

  /// The customer's pin; null if they only typed an address.
  final LatLng? home;

  /// The driver's position; null when there's no driver to show.
  final LatLng? driver;

  /// The driver's position is old or only assumed (e.g. still at the store):
  /// drawn greyed out so it isn't mistaken for a live fix.
  final bool driverStale;

  /// The driver's position is only assumed (they've left the store but haven't
  /// shared a location yet), so it's [store]. Drawn beside the store pin rather
  /// than on top of it, so the two don't hide each other.
  final bool driverAssumed;

  /// Tests pass a blank provider so no network tile requests are made.
  final TileProvider? tileProvider;

  /// 0 when the map fills the screen behind other widgets.
  final double borderRadius;

  /// Parts of the map that other widgets cover (cards on top, a sheet below):
  /// the pins are framed clear of them, and the credit and the recenter
  /// button stay in the visible part.
  final double topInset;
  final double bottomInset;

  @override
  State<OrderMap> createState() => _OrderMapState();
}

class _OrderMapState extends State<OrderMap> {
  final _controller = MapController();
  bool _ready = false;
  bool _userMoved = false;

  List<LatLng> get _points => [widget.store, if (widget.home != null) widget.home!, if (widget.driver != null) widget.driver!];

  CameraFit _fit() => CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_points),
        // Extra room on top for the marker labels.
        padding: EdgeInsets.fromLTRB(48, 84 + widget.topInset, 48, 48 + widget.bottomInset),
        maxZoom: 16,
      );

  @override
  void didUpdateWidget(OrderMap old) {
    super.didUpdateWidget(old);
    final moved = old.driver != widget.driver || old.home != widget.home || old.store != widget.store;
    if (moved && _ready && !_userMoved && _points.length > 1) {
      _controller.fitCamera(_fit());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recenter() {
    setState(() => _userMoved = false);
    if (_points.length > 1) {
      _controller.fitCamera(_fit());
    } else {
      _controller.move(widget.store, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    final driver = widget.driver;
    final animate = !MediaQuery.disableAnimationsOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.store,
              initialZoom: 15,
              initialCameraFit: _points.length > 1 ? _fit() : null,
              minZoom: 5,
              maxZoom: 18,
              // No rotation: a rotated map in an RTL screen is disorienting.
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onMapReady: () => _ready = true,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && !_userMoved) setState(() => _userMoved = true);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // Required by OpenStreetMap's tile usage policy.
                userAgentPackageName: 'com.aswaqaltaibat.aswaq_altaibat',
                tileProvider: widget.tileProvider,
              ),
              if (home != null)
                PolylineLayer(
                  polylines: [
                    if (driver == null)
                      Polyline(points: [widget.store, home], strokeWidth: 4, color: AppColors.primary.withValues(alpha: 0.55), isDotted: true)
                    else ...[
                      // Where the driver has been (solid) and where they're headed (dotted).
                      Polyline(points: [widget.store, driver], strokeWidth: 5, color: AppColors.accent),
                      Polyline(points: [driver, home], strokeWidth: 4, color: AppColors.primary.withValues(alpha: 0.55), isDotted: true),
                    ],
                  ],
                ),
              MarkerLayer(
                markers: [
                  _pin(widget.store, key: 'store', label: 'المتجر', icon: Icons.storefront, color: AppColors.primary),
                  if (home != null) _pin(home, key: 'home', label: 'منزلك', icon: Icons.home, color: AppColors.accent),
                ],
              ),
              if (driver != null)
                // The driver glides to each new position instead of jumping.
                TweenAnimationBuilder<LatLng>(
                  tween: _LatLngTween(end: driver),
                  duration: animate ? const Duration(milliseconds: 900) : Duration.zero,
                  curve: Curves.easeInOut,
                  builder: (context, point, _) => MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 96,
                        height: _driverHeight,
                        // Beside the point, not centred on it, while only assumed.
                        alignment: widget.driverAssumed ? const Alignment(1.5, 0) : Alignment.center,
                        child: _DriverMarker(stale: widget.driverStale),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // The credit OpenStreetMap's tile policy requires. Our own strip rather
          // than the library's, which overflows at large accessibility text sizes.
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.bottomInset),
              child: const IgnorePointer(child: _Attribution()),
            ),
          ),
          if (_userMoved)
            PositionedDirectional(
              top: 8 + widget.topInset,
              end: 8,
              child: FloatingActionButton.small(
                key: const ValueKey('map-recenter'),
                heroTag: 'order-map-recenter',
                tooltip: 'إعادة توسيط الخريطة',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                onPressed: _recenter,
                child: const Icon(Icons.center_focus_strong),
              ),
            ),
        ],
      ),
    );
  }

  /// A pin whose tip sits exactly on [point], with a name tag above it.
  Marker _pin(LatLng point, {required String key, required String label, required IconData icon, required Color color}) {
    return Marker(
      point: point,
      width: 96,
      height: _pinHeight,
      alignment: Alignment.topCenter, // the whole pin sits above the point: its tip marks the spot
      child: Column(
        key: ValueKey('map-marker-$key'),
        mainAxisAlignment: MainAxisAlignment.end, // contents sit on the tip, whatever the box size
        children: [
          _Tag(label),
          const SizedBox(height: 2),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4)],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Icon(Icons.arrow_drop_down, color: color, size: 18, shadows: const [Shadow(color: Color(0x40000000), blurRadius: 2)]),
        ],
      ),
    );
  }
}

// Marker geometry. Fixed so a marker never overflows its box (font metrics vary
// by device): name tag + gap + circle + pin tip.
const double _tagHeight = 22;
const double _pinHeight = _tagHeight + 2 + 34 + 18 + 4;
const double _driverCircle = 40;
// The driver is anchored by the circle's centre, so the circle sits in the middle
// of the box with the tag above it and equal empty space below.
const double _driverHeight = 2 * (_tagHeight + 2 + _driverCircle / 2);

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xCCFFFFFF),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
      ),
      child: const Text(
        '© OpenStreetMap contributors',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling, // a fixed, small credit line
        style: TextStyle(fontSize: 10, color: Color(0xFF333333)),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _tagHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
      ),
      child: Text(
        text,
        maxLines: 1,
        style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700, height: 1.1),
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker({required this.stale});

  final bool stale;

  @override
  Widget build(BuildContext context) {
    final color = stale ? AppColors.textMuted : AppColors.success;
    return Column(
      key: const ValueKey('map-marker-driver'),
      children: [
        const _Tag('السائق'),
        const SizedBox(height: 2),
        Container(
          width: _driverCircle,
          height: _driverCircle,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
          ),
          child: const Icon(Icons.delivery_dining, color: Colors.white, size: 22),
        ),
        // Balances the tag above, so the circle's centre is the marker's centre.
        const Spacer(),
      ],
    );
  }
}

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({super.end});

  @override
  LatLng lerp(double t) => LatLng(
        begin!.latitude + (end!.latitude - begin!.latitude) * t,
        begin!.longitude + (end!.longitude - begin!.longitude) * t,
      );
}
