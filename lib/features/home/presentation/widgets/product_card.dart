import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../domain/entities/product.dart';
import 'product_image.dart';

/// A single product tile for the home/category grid: picture (or its category's), discount
/// badge, bilingual-ready name, JOD price (with strikethrough original
/// when discounted), and a quantity stepper wired straight to the cart.
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartProvider.select(
      (cart) => cart[product.id]?.quantity ?? 0,
    ));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Stack(
                  children: [
                    Positioned.fill(child: ProductImage(product: product)),
                    if (product.hasDiscount)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _DiscountBadge(percent: product.discountPercent),
                      ),
                    if (product.isOutOfStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'غير متوفر',
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nameAr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (product.unit != null) ...[
                    const SizedBox(height: 2),
                    Text(product.unit!, style: AppTextStyles.caption),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CurrencyFormatter.jod(product.displayPrice),
                              style: AppTextStyles.price,
                            ),
                            if (product.hasDiscount)
                              Text(
                                CurrencyFormatter.jod(product.price),
                                style: AppTextStyles.priceStrikethrough,
                              ),
                          ],
                        ),
                      ),
                      _QuantityStepper(
                        product: product,
                        quantity: quantity,
                        disabled: product.isOutOfStock,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.discount,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$percent% OFF',
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({
    required this.product,
    required this.quantity,
    required this.disabled,
  });

  final Product product;
  final int quantity;
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (disabled) return const SizedBox.shrink();

    void handleAdd() {
      final added = ref.read(cartProvider.notifier).add(product);
      if (!added) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('الكمية المتوفرة من "${product.nameAr}" هي ${product.stockQuantity} فقط.')),
        );
      }
    }

    if (quantity == 0) {
      return _StepperButton(icon: Icons.add, onTap: handleAdd, filled: true);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: () => ref.read(cartProvider.notifier).decrement(product),
          ),
          SizedBox(
            width: 20,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: handleAdd),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: filled ? Colors.white : Colors.white),
      ),
    );

    if (!filled) return button;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: button,
    );
  }
}
