import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../home/domain/entities/product.dart';
import '../../domain/entities/cart_item.dart';

/// Mirrors the signed-in user's cart to `cart_items` (see
/// supabase/005_cart_items.sql) so it survives app restarts and syncs across
/// devices. Never called for guests — [CartNotifier] gates every call on
/// having a signed-in `user_id` first.
class CartRepository {
  CartRepository(this._client);

  final SupabaseClient _client;

  Future<List<CartItem>> fetchCart(String userId) async {
    final rows = await _client
        .from('cart_items')
        .select('quantity, products(*)')
        .eq('user_id', userId);

    final items = <CartItem>[];
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      // The product join comes back null if the product was deleted, or
      // deactivated (RLS on `products` hides inactive rows even through this
      // embed) — either way it's no longer purchasable, so drop it rather
      // than surface a cart row with no product.
      final productJson = map['products'] as Map<String, dynamic>?;
      if (productJson == null) continue;
      items.add(CartItem(
        product: Product.fromJson(productJson),
        quantity: map['quantity'] as int,
      ));
    }
    return items;
  }

  Future<void> upsertItem(String userId, String productId, int quantity) {
    return _client.from('cart_items').upsert(
      {'user_id': userId, 'product_id': productId, 'quantity': quantity},
      onConflict: 'user_id,product_id',
    );
  }

  Future<void> deleteItem(String userId, String productId) {
    return _client
        .from('cart_items')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
  }

  Future<void> clearCart(String userId) {
    return _client.from('cart_items').delete().eq('user_id', userId);
  }
}
