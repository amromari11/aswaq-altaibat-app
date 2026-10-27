import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../sponsors/data/repositories/sponsors_repository.dart';
import '../../data/repositories/home_repository.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(supabaseClientProvider));
});

final sponsorsRepositoryProvider = Provider<SponsorsRepository>((ref) {
  return SponsorsRepository(ref.watch(supabaseClientProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchCategories();
});

final weeklyOffersProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchWeeklyOffers();
});

final latestProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchLatestProducts();
});

final appExclusiveProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchAppExclusive();
});

/// Empty (not an error) for guests — the UI hides the "Order again" row
/// entirely when this resolves to an empty list.
final orderAgainProvider = FutureProvider<List<Product>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(const []);
  return ref.watch(homeRepositoryProvider).fetchOrderAgain(user.id);
});

final categoryProductsProvider = FutureProvider.family<List<Product>, String>((ref, categoryId) {
  return ref.watch(homeRepositoryProvider).fetchByCategory(categoryId);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Product>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(homeRepositoryProvider).search(query);
});
