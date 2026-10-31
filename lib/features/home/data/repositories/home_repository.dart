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

  /// Characters that mean something inside a PostgREST `or=(...)` filter.
  static String _cleanTerm(String query) {
    var term = query;
    for (final ch in [',', '(', ')', '%', '*', '\\']) {
      term = term.replaceAll(ch, ' ');
    }
    return term.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// The `or=` filter for a search box entry: name (either language), plus an
  /// exact SKU match when it looks like a barcode (6+ digits) — the POS
  /// barcode is the product's SKU.
  static String searchFilter(String query) {
    final term = _cleanTerm(query);
    final filters = ['name.ilike.%$term%', 'name_ar.ilike.%$term%'];
    if (RegExp(r'^\d{6,}$').hasMatch(term)) filters.add('sku.eq.$term');
    return filters.join(',');
  }

  Future<List<Product>> search(String query, {int limit = 20}) async {
    if (_cleanTerm(query).isEmpty) return [];

    final rows = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .or(searchFilter(query))
        .limit(limit);

    return _parseProducts(rows);
  }

  /// The best-selling products of the last 30 days (`best_sellers`, backend
  /// migration 016). Empty - not an error - when the function isn't on the
  /// server yet, so Home simply leaves the section out.
  Future<List<Product>> fetchBestSellers({int limit = 20}) async {
    try {
      final rows = await _client.rpc('best_sellers', params: {'p_limit': limit});
      return _parseProducts(rows);
    } on PostgrestException {
      return [];
    }
  }

  /// One active product by id, or null if it is gone or hidden (a banner may point at one).
  Future<Product?> fetchProduct(String id) async {
    final rows =
        await _client.from('products').select().eq('id', id).eq('is_active', true).limit(1);
    final products = _parseProducts(rows);
    return products.isEmpty ? null : products.first;
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
