import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../home/domain/entities/product.dart';
import '../../data/repositories/recommendations_repository.dart';

final recommendationsRepositoryProvider = Provider<RecommendationsRepository>((ref) {
  return RecommendationsRepository(ref.watch(supabaseClientProvider));
});

/// Home screen "قد يعجبك أيضاً": personalized when there's purchase
/// history to use, otherwise the discovery-mix fallback.
final homeRecommendationsProvider = FutureProvider<List<Product>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(recommendationsRepositoryProvider);

  if (user != null) {
    final personalized = await repo.fetchForUser(user.id);
    if (personalized.isNotEmpty) return personalized;
  }
  return repo.fetchDiscoveryMix();
});

/// Cart page "مكملات لسلعتك": derived live from whatever's currently in
/// the cart, so it updates as items are added/removed.
final cartComplementaryProvider = FutureProvider<List<Product>>((ref) async {
  final items = ref.watch(cartItemsListProvider);
  if (items.isEmpty) return [];

  final categoryIds = items.map((item) => item.product.categoryId).toSet().toList();
  final excludeProductIds = items.map((item) => item.product.id).toList();

  return ref.watch(recommendationsRepositoryProvider).fetchComplementary(
        categoryIds: categoryIds,
        excludeProductIds: excludeProductIds,
      );
});
