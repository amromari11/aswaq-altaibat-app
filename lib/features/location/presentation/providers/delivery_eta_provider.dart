import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_providers.dart';

/// "30–35" minutes: the zone's estimate and the five minutes before it.
typedef EtaRange = ({int low, int high});

EtaRange etaRangeFor(int etaMinutes) {
  final high = math.max(etaMinutes, 5);
  return (low: high <= 10 ? high : high - 5, high: high);
}

/// '30–35 دقيقة' ('20 دقيقة' when the range is a single number).
String etaRangeLabel(EtaRange range, {bool short = false}) {
  final unit = short ? 'د' : 'دقيقة';
  return range.low == range.high ? '${range.high} $unit' : '${range.low}–${range.high} $unit';
}

/// Delivery time to quote: the selected address's zone, else the fastest zone;
/// null until zones have loaded.
final deliveryEtaProvider = Provider<EtaRange?>((ref) {
  final zone = ref.watch(selectedZoneProvider);
  if (zone != null) return etaRangeFor(zone.etaMinutes);
  final zones = ref.watch(zonesProvider).valueOrNull;
  if (zones == null || zones.isEmpty) return null;
  return etaRangeFor(zones.map((z) => z.etaMinutes).reduce(math.min));
});
