import '../../domain/entities/delivery_zone.dart';

/// Static list of Zarqa delivery zones. Fees/minimums here are placeholders
/// for the UI — confirm real values with the store before launch.
class ZonesRepository {
  const ZonesRepository();

  static const List<DeliveryZone> zones = [
    DeliveryZone(id: 'zarqa_center', nameAr: 'وسط الزرقاء', deliveryFeeJod: 1.0, minOrderJod: 5, etaMinutes: 25),
    DeliveryZone(id: 'new_zarqa', nameAr: 'الزرقاء الجديدة', deliveryFeeJod: 1.5, minOrderJod: 8, etaMinutes: 35),
    DeliveryZone(id: 'hashmiyya', nameAr: 'الهاشمية', deliveryFeeJod: 2.0, minOrderJod: 10, etaMinutes: 45),
    DeliveryZone(id: 'russeifa', nameAr: 'الرصيفة', deliveryFeeJod: 1.5, minOrderJod: 8, etaMinutes: 35),
    DeliveryZone(id: 'awajan', nameAr: 'عوجان', deliveryFeeJod: 1.5, minOrderJod: 8, etaMinutes: 35),
    DeliveryZone(id: 'sukhna', nameAr: 'السخنة', deliveryFeeJod: 2.5, minOrderJod: 12, etaMinutes: 55),
  ];

  List<DeliveryZone> all() => zones;

  DeliveryZone? byId(String? id) {
    for (final zone in zones) {
      if (zone.id == id) return zone;
    }
    return null;
  }
}
