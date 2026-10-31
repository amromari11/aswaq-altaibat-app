import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../domain/entities/product.dart';
import 'product_image.dart';

/// Sticky bar pinned above the bottom nav once the cart has items: small
/// pictures of what is in it, "N items · total", what the discounts saved (or
/// how far the free-delivery goal is), and a "view cart" button.
class FloatingCartBar extends ConsumerWidget {
  const FloatingCartBar({super.key, required this.onViewCart});

  final VoidCallback onViewCart;

  static const savingsKey = ValueKey('cart-bar-savings');
  static const freeDeliveryKey = ValueKey('cart-bar-free-delivery');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(cartItemCountProvider);
    if (itemCount == 0) return const SizedBox.shrink();

    final subtotal = ref.watch(cartSubtotalProvider);
    final savings = ref.watch(cartSavingsProvider);
    final remaining = ref.watch(freeDeliveryRemainingProvider);
    final products = ref.watch(cartItemsListProvider).map((item) => item.product).toList();

    final String note;
    final Key noteKey;
    if (savings > 0) {
      note = 'وفّرت ${CurrencyFormatter.jod(savings)}';
      noteKey = savingsKey;
    } else if (remaining <= 0) {
      note = 'التوصيل مجاني 🎉';
      noteKey = freeDeliveryKey;
    } else {
      note = 'أضف ${CurrencyFormatter.jod(remaining)} لتوصيل مجاني';
      noteKey = freeDeliveryKey;
    }

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _Thumbs(products: products),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$itemCount ${itemCount == 1 ? 'منتج' : 'منتجات'} · ${CurrencyFormatter.jod(subtotal)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    note,
                    key: noteKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: savings > 0 ? const Color(0xFF9FE5B5) : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onViewCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('عرض السلة', style: AppTextStyles.button.copyWith(color: AppColors.primary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to three overlapping round pictures of what is in the cart.
class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.products});

  final List<Product> products;

  static const _size = 34.0;
  static const _step = 22.0;

  @override
  Widget build(BuildContext context) {
    final shown = products.take(3).toList();
    return SizedBox(
      width: _size + _step * (shown.length - 1),
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(
              start: i * _step,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: ProductThumb(product: shown[i]),
              ),
            ),
        ],
      ),
    );
  }
}
