/// A delivery area in Zarqa with its own fee, minimum order and ETA.
///
/// Zones are static for now (see `ZonesRepository`); the shape mirrors what a
/// `delivery_zones` table would hold, so swapping in Supabase later only
/// touches the repository.
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.nameAr,
    required this.deliveryFeeJod,
    required this.minOrderJod,
    required this.etaMinutes,
  });

  final String id;
  final String nameAr;
  final double deliveryFeeJod;
  final double minOrderJod;
  final int etaMinutes;
}
