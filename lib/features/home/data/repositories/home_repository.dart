import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';

class HomeRepository {
  HomeRepository(this._client);

  final SupabaseClient _client;

  Future<List<Category>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true)
        .order('name_ar', ascending: true);

    return (rows as List).map((row) => Category.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<List<Product>> fetchWeeklyOffers({int limit = 10}) async {
    final rows = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .eq('is_weekly_offer', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return _parseProducts(rows);
  }

  Future<List<Product>> fetchAppExclusive({int limit = 10}) async {
    final rows = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .eq('is_app_exclusive', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return _parseProducts(rows);
  }

  /// Fallback for the home grid when there are no weekly offers to show —
  /// otherwise the home screen would default to an empty state despite a
  /// full catalog existing. Newest-first general browsing, not tied to any
  /// promo flag.
  Future<List<Product>> fetchLatestProducts({int limit = 20}) async {
    final rows = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return _parseProducts(rows);
  }

  Future<List<Product>> fetchByCategory(String categoryId, {int limit = 40}) async {
    final rows = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .eq('category_id', categoryId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _parseProducts(rows);
  }

  Future<List<Product>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final rows = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .or('name.ilike.%$query%,name_ar.ilike.%$query%')
        .limit(limit);

    return _parseProducts(rows);
  }

  /// "Order again" — the most recent distinct products this signed-in user
  /// has actually bought, newest first. Empty for guests (no `user_id` to
  /// query), which the UI treats as "hide this row" rather than an error.
  Future<List<Product>> fetchOrderAgain(String userId, {int limit = 10}) async {
    final rows = await _client
        .from('order_items')
        .select('product_id, created_at, orders!inner(user_id), products(*)')
        .eq('orders.user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit * 3); // over-fetch; de-duplicate by product below

    final seen = <String>{};
    final products = <Product>[];
    for (final row in rows as List) {
      final productJson = (row as Map<String, dynamic>)['products'];
      if (productJson == null) continue;
      final product = Product.fromJson(productJson as Map<String, dynamic>);
      if (seen.add(product.id)) {
        products.add(product);
        if (products.length >= limit) break;
      }
    }
    return products;
  }

  List<Product> _parseProducts(Object? rows) {
    return (rows as List).map((row) => Product.fromJson(row as Map<String, dynamic>)).toList();
  }
}
