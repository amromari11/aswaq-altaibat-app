import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../home/domain/entities/product.dart';
import '../../domain/entities/cart_item.dart';

/// One cart line that can't be fulfilled as-is: either [product] has gone
/// out of stock entirely ([availableQuantity] 0), or there's less of it
/// left than the cart wants.
class StockIssue {
  const StockIssue({
    required this.product,
    required this.requestedQuantity,
    required this.availableQuantity,
  });

  final Product product;
  final int requestedQuantity;
  final int availableQuantity;
}

class CheckoutRepository {
  CheckoutRepository(this._client);

  final SupabaseClient _client;

  /// Re-reads current stock for every cart line right before checkout —
  /// the `Product` snapshots in the cart can be stale (added minutes or
  /// days ago, or synced down from another device via cart_items), so this
  /// is the authoritative check, not the UI's add-to-cart guard.
  Future<List<StockIssue>> checkStock(List<CartItem> items) async {
    if (items.isEmpty) return [];

    final ids = items.map((item) => item.product.id).toList();
    final rows = await _client.from('products').select().inFilter('id', ids);
    final freshById = {
      for (final row in rows as List)
        (row as Map<String, dynamic>)['id'] as String: Product.fromJson(row),
    };

    final issues = <StockIssue>[];
    for (final item in items) {
      final fresh = freshById[item.product.id];
      // Missing entirely means deleted or deactivated since being added —
      // treat the same as out of stock.
      if (fresh == null || fresh.isOutOfStock) {
        issues.add(StockIssue(
          product: fresh ?? item.product,
          requestedQuantity: item.quantity,
          availableQuantity: 0,
        ));
      } else if (fresh.stockQuantity > 0 && item.quantity > fresh.stockQuantity) {
        issues.add(StockIssue(
          product: fresh,
          requestedQuantity: item.quantity,
          availableQuantity: fresh.stockQuantity,
        ));
      }
    }
    return issues;
  }

  /// Creates the `orders` row and its `order_items`, matching
  /// supabase/schema.sql exactly. Requires a real signed-in user — RLS
  /// ("Users can create their own orders") checks `auth.uid() = user_id`,
  /// so this fails for a guest session regardless of what's passed here;
  /// the UI gates on sign-in before ever reaching this call (see
  /// CheckoutController.placeOrder).
  ///
  /// Prices are sent as full-precision doubles, not pre-rounded — same
  /// reasoning as the rest of the app: the database column decides its own
  /// precision, and this stays correct automatically once
  /// supabase/004_jod_precision.sql (numeric(10,3)) is applied.
  Future<String> placeOrder({
    required String userId,
    required List<CartItem> items,
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String paymentMethod = 'cash',
    String? notes,
    double? deliveryFeeOverride,
    String? zoneId,
    String? addressId,
  }) async {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final deliveryFee = subtotal >= AppConfig.freeDeliveryThresholdJod
        ? 0.0
        : (deliveryFeeOverride ?? AppConfig.deliveryFeeJod);
    final total = subtotal + deliveryFee;

    final orderRow = await _client
        .from('orders')
        .insert({
          'user_id': userId,
          'subtotal': subtotal,
          'delivery_fee': deliveryFee,
          'total_price': total,
          'delivery_address': deliveryAddress,
          // supabase/schema.sql's delivery_lat/delivery_lng are nullable —
          // the map pin is a refinement on top of the typed address, not a
          // requirement, so orders placed without it still insert fine.
          if (deliveryLat != null) 'delivery_lat': deliveryLat,
          if (deliveryLng != null) 'delivery_lng': deliveryLng,
          'payment_method': paymentMethod,
          // orders.zone_id / address_id (backend supabase/007) — for
          // admin reporting; delivery_address above stays the snapshot.
          if (zoneId != null) 'zone_id': zoneId,
          if (addressId != null) 'address_id': addressId,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .select('id')
        .single();

    final orderId = orderRow['id'] as String;

    final itemRows = items
        .map(
          (item) => {
            'order_id': orderId,
            'product_id': item.product.id,
            'quantity': item.quantity,
            'unit_price': item.product.displayPrice,
            'line_total': item.lineTotal,
          },
        )
        .toList();

    await _client.from('order_items').insert(itemRows);

    return orderId;
  }
}
