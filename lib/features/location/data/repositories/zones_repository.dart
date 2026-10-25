import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/delivery_zone.dart';

/// Reads `delivery_zones` — public catalog data (RLS: active rows only),
/// managed from the admin dashboard.
class ZonesRepository {
  ZonesRepository(this._client);

  final SupabaseClient _client;

  Future<List<DeliveryZone>> fetchActive() async {
    final rows = await _client
        .from('delivery_zones')
        .select('id, name_ar, delivery_fee, min_order_amount, eta_minutes')
        .order('display_order', ascending: true)
        .order('name_ar', ascending: true);
    return [for (final row in rows as List) DeliveryZone.fromJson(row as Map<String, dynamic>)];
  }
}
