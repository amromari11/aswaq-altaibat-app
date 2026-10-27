import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/providers/home_providers.dart';

/// The picture of the category with this id, or null while categories are loading / when it has none.
/// Products without a picture of their own borrow it.
final categoryImageUrlProvider = Provider.family<String?, String>((ref, categoryId) {
  final categories = ref.watch(categoriesProvider).valueOrNull;
  if (categories == null) return null;
  for (final category in categories) {
    if (category.id == categoryId) return category.imageUrl;
  }
  return null;
});
