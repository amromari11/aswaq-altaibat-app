/// A delivery area in Zarqa with its own fee, minimum order and ETA.
/// Mirrors `public.delivery_zones` (see backend supabase/007).
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

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String,
      deliveryFeeJod: (json['delivery_fee'] as num).toDouble(),
      minOrderJod: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 30,
    );
  }
}
