import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionResult { granted, serviceDisabled, denied, deniedForever }

/// Thin wrapper around `geolocator` (permissions + current GPS fix) and
/// `geocoding` (reverse geocoding) for the delivery location picker.
class LocationService {
  /// Zarqa, Jordan — used as the map's default camera target when GPS isn't
  /// available yet (permission not granted, or still resolving).
  static const double zarqaFallbackLat = 32.0727;
  static const double zarqaFallbackLng = 36.0876;

  Future<LocationPermissionResult> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionResult.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionResult.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionResult.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionResult.denied;
    }
  }

  Future<Position> getCurrentPosition() {
    // geolocator 10.x's getCurrentPosition still takes `desiredAccuracy`
    // directly — the `locationSettings:` param was added in a later major.
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  /// Best-effort reverse geocode. The device geocoder can legitimately find
  /// nothing (offline, or a point with no address data), so this falls back
  /// to a plain coordinate string rather than throwing.
  Future<String> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return _coordinateFallback(latitude, longitude);

      final place = placemarks.first;
      final parts = [place.street, place.subLocality, place.locality, place.administrativeArea]
          .where((part) => part != null && part.trim().isNotEmpty)
          .toSet() // drop accidental duplicates (e.g. street == locality)
          .join('، ');

      return parts.isEmpty ? _coordinateFallback(latitude, longitude) : parts;
    } catch (_) {
      return _coordinateFallback(latitude, longitude);
    }
  }

  String _coordinateFallback(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}
