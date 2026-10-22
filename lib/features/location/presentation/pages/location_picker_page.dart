import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/location_service.dart';
import '../../domain/entities/delivery_location.dart';
import '../providers/location_providers.dart';

/// Full-screen map for picking/fine-tuning the delivery pin. Pushed from
/// [CheckoutPage] with `context.push<DeliveryLocation>('/location-picker')`;
/// pops with a [DeliveryLocation] on confirm, or `null` if the user backs out.
class LocationPickerPage extends ConsumerStatefulWidget {
  const LocationPickerPage({super.key});

  @override
  ConsumerState<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends ConsumerState<LocationPickerPage> {
  static const LatLng _zarqaFallback =
      LatLng(LocationService.zarqaFallbackLat, LocationService.zarqaFallbackLng);

  GoogleMapController? _mapController;
  LatLng _selected = _zarqaFallback;
  final _addressController = TextEditingController();
  bool _locating = true;
  bool _resolvingAddress = false;

  @override
  void initState() {
    super.initState();
    // Requirement: fetch the user's current location automatically when this
    // screen opens, rather than waiting for them to tap a button first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentLocation());
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final service = ref.read(locationServiceProvider);
    final result = await service.ensurePermission();

    if (!mounted) return;

    switch (result) {
      case LocationPermissionResult.granted:
        try {
          final position = await service.getCurrentPosition();
          await _moveTo(LatLng(position.latitude, position.longitude), animate: true);
        } catch (_) {
          _showSnack('تعذر تحديد موقعك الحالي. حدد الموقع يدوياً على الخريطة.');
        }
      case LocationPermissionResult.serviceDisabled:
        _showSnack('خدمة الموقع غير مفعّلة على جهازك. يمكنك تحديد الموقع يدوياً.');
      case LocationPermissionResult.denied:
        _showSnack('لم يتم السماح بالوصول للموقع. يمكنك تحديد الموقع يدوياً على الخريطة.');
      case LocationPermissionResult.deniedForever:
        _showSnack('إذن الموقع مرفوض دائماً. فعّله من إعدادات الجهاز، أو حدد الموقع يدوياً.');
    }

    if (mounted) setState(() => _locating = false);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _moveTo(LatLng point, {bool animate = false}) async {
    setState(() => _selected = point);
    if (animate) {
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
    }
    await _resolveAddress(point);
  }

  Future<void> _resolveAddress(LatLng point) async {
    setState(() => _resolvingAddress = true);
    final address = await ref.read(locationServiceProvider).reverseGeocode(
          point.latitude,
          point.longitude,
        );
    if (!mounted) return;
    setState(() {
      _addressController.text = address;
      _resolvingAddress = false;
    });
  }

  void _confirm() {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showSnack('الرجاء إدخال عنوان التوصيل.');
      return;
    }
    context.pop(
      DeliveryLocation(
        latitude: _selected.latitude,
        longitude: _selected.longitude,
        address: address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حدد موقع التوصيل'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: _zarqaFallback, zoom: 13),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (point) => _moveTo(point),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('delivery-pin'),
                position: _selected,
                draggable: true,
                onDragEnd: (point) => _moveTo(point),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
          ),
          if (_locating)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'use-current-location',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              onPressed: _locating ? null : _useCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 12)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('عنوان التوصيل', style: AppTextStyles.h3),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'الحي، الشارع، رقم المبنى...',
                        suffixIcon: _resolvingAddress
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _confirm,
                      child: const Text('تأكيد الموقع'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
