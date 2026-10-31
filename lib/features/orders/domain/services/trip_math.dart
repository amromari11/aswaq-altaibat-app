import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../entities/order_tracking.dart';

// roundResult: false - by default the library rounds to whole units, i.e. whole kilometres here.
const _distance = Distance(roundResult: false);

/// How far along the trip from the store to the customer the driver is.
class TripProgress {
  const TripProgress({required this.remainingKm, required this.fraction});

  /// Straight-line distance still to go.
  final double remainingKm;

  /// 0 = at the store, 1 = at the door.
  final double fraction;
}

/// Null when the customer didn't drop a pin (nothing to measure to).
/// [driver] null means the driver is still assumed to be at the store.
TripProgress? tripProgress({required LatLng store, required LatLng? home, required LatLng? driver}) {
  if (home == null) return null;
  final total = _distance.as(LengthUnit.Kilometer, store, home);
  final remaining = _distance.as(LengthUnit.Kilometer, driver ?? store, home);
  final fraction = total <= 0.02 ? 1.0 : (1 - remaining / total).clamp(0.0, 1.0);
  return TripProgress(remainingKm: remaining, fraction: fraction);
}

/// '450 م' under a kilometre, else '1.2 كم'.
String distanceLabel(double km) {
  if (km < 0.95) return '${(math.max(km, 0.01) * 100).round() * 10} م';
  return '${km.toStringAsFixed(1)} كم';
}

/// Whole minutes until [order] is due (rounded up, never negative); null when
/// the order has no arrival estimate (pickup, scheduled, or no zone ETA).
int? minutesLeft(OrderTracking order, DateTime now) {
  final due = order.expectedBy;
  if (due == null) return null;
  final seconds = due.difference(now).inSeconds;
  return seconds <= 0 ? 0 : (seconds / 60).ceil();
}

/// 'لحظات' / 'دقيقة' / 'دقيقتان' / '5 دقائق' / '15 دقيقة'.
String minutesWords(int minutes) {
  if (minutes <= 0) return 'لحظات';
  if (minutes == 1) return 'دقيقة';
  if (minutes == 2) return 'دقيقتان';
  if (minutes <= 10) return '$minutes دقائق';
  return '$minutes دقيقة';
}
