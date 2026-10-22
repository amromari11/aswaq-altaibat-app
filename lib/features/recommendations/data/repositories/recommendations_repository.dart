import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../home/domain/entities/product.dart';

/// Heuristic recommendations — no ML model and no view/click tracking in
/// the schema, so this leans on two real signals the schema *does* have:
/// past purchases (order_items), and a "popular" stand-in (see
/// [fetchDiscoveryMix]'s doc comment for exactly what that means here).
class RecommendationsRepository {
  RecommendationsRepository(this._client);

  final SupabaseClient _client;

  /// "قد يعجبك أيضاً" for a signed-in user with order history: other
  /// products from categories they've actually bought from before,
  /// excluding products they've already bought. Returns empty for a user
  /// with no order history — callers should fall back to
  /// [fetchDiscoveryMix] in that case.
  Future<List<Product>> fetchForUser(String userId, {int limit = 10}) async {
    final purchasedRows = await _client
        .from('order_items')
        .select('product_id, orders!inner(user_id), products(category_id)')
        .eq('orders.user_id', userId)
        .limit(200);

    final purchasedProductIds = <String>{};
    final categoryIds = <String>{};
    for (final row in purchasedRows as List) {
      final r = row as Map<String, dynamic>;
      purchasedProductIds.add(r['product_id'] as String);
      final product = r['products'] as Map<String, dynamic>?;
      final categoryId = product?['category_id'] as String?;
      if (categoryId != null) categoryIds.add(categoryId);
    }

    if (categoryIds.isEmpty) return [];

    final rows = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .inFilter('category_id', categoryIds.toList())
        .order('created_at', ascending: false)
        .limit(limit + purchasedProductIds.length);

    return (rows as List)
        .map((row) => Product.fromJson(row as Map<String, dynamic>))
        .where((product) => !purchasedProductIds.contains(product.id))
        .take(limit)
        .toList();
  }

  /// Fallback for guests and users with no purchase history yet: a sample
  /// spread across several categories rather than everything from one.
  /// Standing in for "popular categories" — the schema has no sales/view
  /// counts to rank by, so this is honestly just variety, not a ranked
  /// popularity signal.
  Future<List<Product>> fetchDiscoveryMix({int limit = 10}) async {
    final categoryRows = await _client
        .from('categories')
        .select('id')
        .eq('is_active', true)
        .limit(8);
    final categoryIds =
        (categoryRows as List).map((row) => (row as Map<String, dynamic>)['id'] as String).toList();
    if (categoryIds.isEmpty) return [];

    final perCategory = (limit / categoryIds.length).ceil().clamp(1, limit);
    final results = <Product>[];
    for (final categoryId in categoryIds) {
      if (results.length >= limit) break;
      final rows = await _client
          .from('products')
          .select()
          .eq('is_active', true)
          .eq('category_id', categoryId)
          .order('created_at', ascending: false)
          .limit(perCategory);
      results.addAll((rows as List).map((row) => Product.fromJson(row as Map<String, dynamic>)));
    }
    return results.take(limit).toList();
  }

  /// "مكملات لسلعتك" on the cart page: other products from the same
  /// categories as what's already in the cart, excluding those items.
  Future<List<Product>> fetchComplementary({
    required List<String> categoryIds,
    required List<String> excludeProductIds,
    int limit = 10,
  }) async {
    if (categoryIds.isEmpty) return [];

    final rows = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .inFilter('category_id', categoryIds)
        .order('created_at', ascending: false)
        .limit(limit + excludeProductIds.length);

    return (rows as List)
        .map((row) => Product.fromJson(row as Map<String, dynamic>))
        .where((product) => !excludeProductIds.contains(product.id))
        .take(limit)
        .toList();
  }
}
