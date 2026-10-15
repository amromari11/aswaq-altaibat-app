import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../sponsors/presentation/widgets/sponsored_badge.dart';
import '../providers/cart_provider.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartItemsListProvider);
    final subtotal = ref.watch(cartSubtotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('السلة')),
      body: items.isEmpty
          ? Center(
              child: Text('سلتك فارغة', style: AppTextStyles.body),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.shopping_basket_outlined,
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.nameAr, style: AppTextStyles.bodyMedium),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.jod(item.product.displayPrice),
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    ref.read(cartProvider.notifier).decrement(item.product),
                                icon: const Icon(Icons.remove_circle_outline),
                                color: AppColors.primary,
                              ),
                              Text('${item.quantity}', style: AppTextStyles.bodyMedium),
                              IconButton(
                                onPressed: () =>
                                    ref.read(cartProvider.notifier).add(item.product),
                                icon: const Icon(Icons.add_circle_outline),
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Retail-media cross-sell slot: a sponsor-paid "add this
                // before checkout" banner. Wire to the sponsors repository's
                // in_cart-placement banners once that query is added.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SponsoredBadge(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'أضف منتج الرعاة بسعر خاص قبل الشراء',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الإجمالي', style: AppTextStyles.h3),
                          Text(CurrencyFormatter.jod(subtotal), style: AppTextStyles.h3),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: wire to checkout — create an `orders` row
                          // + `order_items` rows via Supabase, matching
                          // supabase/schema.sql on the backend.
                        },
                        child: const Text('متابعة الطلب'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
