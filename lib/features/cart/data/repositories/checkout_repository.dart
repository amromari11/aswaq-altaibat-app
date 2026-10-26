import 'package:supabase_flutter/supabase_flutter.dart';

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

/// `place_order` refused the order. [code] is the database function's error
/// message (see backend supabase/008): `below_minimum`, `out_of_stock`,
/// `insufficient_stock`, `unknown_product`, `invalid_phone`, `invalid_name`,
/// `invalid_address`, `invalid_items`, `invalid_zone`, `too_many_orders`.
class OrderRejectedException implements Exception {
  OrderRejectedException(this.code);

  final String code;

  @override
  String toString() => 'OrderRejectedException($code)';
}

class CheckoutRepository {
  CheckoutRepository(this._client);

  final SupabaseClient _client;

  /// Re-reads current stock for every cart line right before checkout —
  /// the `Product` snapshots in the cart can be stale (added minutes or
  /// days ago, or synced down from another device via cart_items), so this
  /// is the authoritative check, not the UI's add-to-cart guard. (The
  /// database re-checks inside `place_order` too; this exists to *reconcile*
  /// the cart and tell the customer exactly what changed.)
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

  /// Places the order through the `place_order` database function, which
  /// works for guests and signed-in users alike. Only *what* is wanted is
  /// sent — product ids and quantities. Prices, delivery fee, minimum order
  /// and totals are computed by the database, never trusted from the phone —
  /// and the order and its items are written in one transaction. The
  /// function also creates/updates the customer by phone number.
  ///
  /// [customerPhone] must already be normalized E.164
  /// (see `JordanPhone.normalize`). Throws [OrderRejectedException] when the
  /// database refuses the order.
  Future<String> placeOrder({
    required String customerName,
    required String customerPhone,
    required List<CartItem> items,
    required String deliveryAddress,
    required String zoneId,
    String? addressId,
    double? deliveryLat,
    double? deliveryLng,
    String? notes,
  }) async {
    try {
      final id = await _client.rpc('place_order', params: {
        'p_customer_name': customerName,
        'p_customer_phone': customerPhone,
        'p_items': [
          for (final item in items) {'product_id': item.product.id, 'quantity': item.quantity},
        ],
        'p_delivery_address': deliveryAddress,
        'p_zone_id': zoneId,
        'p_address_id': addressId,
        'p_delivery_lat': deliveryLat,
        'p_delivery_lng': deliveryLng,
        'p_notes': notes,
      });
      return id as String;
    } on PostgrestException catch (e) {
      // The function raises plain codes (SQLSTATE P0001) — anything else is
      // a transport/permission problem and stays a generic failure.
      if (e.code == 'P0001') throw OrderRejectedException(e.message);
      rethrow;
    }
  }
}
