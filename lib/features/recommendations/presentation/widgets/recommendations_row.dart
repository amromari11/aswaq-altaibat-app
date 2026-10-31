import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../home/domain/entities/product.dart';
import '../../../home/presentation/widgets/product_card.dart';

/// Reused for both "قد يعجبك أيضاً" (home) and "مكملات لسلعتك" (cart) —
/// same horizontal-row presentation, different provider feeding it.
/// Hides itself entirely while loading/empty/errored rather than showing
/// a skeleton or error message, since this is a supplementary section,
/// not core content the user is waiting on.
class RecommendationsRow extends ConsumerWidget {
  const RecommendationsRow({super.key, required this.title, required this.provider});

  final String title;
  final ProviderListenable<AsyncValue<List<Product>>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProducts = ref.watch(provider);

    return asyncProducts.maybeWhen(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.h2),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 140,
                  child: ProductCard(product: products[index]),
                ),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
