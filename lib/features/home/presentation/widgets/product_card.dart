import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../location/presentation/providers/delivery_eta_provider.dart';
import '../../domain/entities/product.dart';
import 'product_image.dart';

/// A single product tile for the home/category grid: picture (or its
/// category's), discount tag, delivery-time badge, name, price (with the
/// original struck through when discounted) and an add / `− 1 +` control wired
/// straight to the cart.
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  static const discountTagKey = ValueKey('product-discount-tag');
  static const etaBadgeKey = ValueKey('product-eta-badge');
  static const addKey = ValueKey('product-add');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartProvider.select(
      (cart) => cart[product.id]?.quantity ?? 0,
    ));
    final eta = ref.watch(deliveryEtaProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
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
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: _DiscountTag(percent: product.discountPercent),
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
                  _MetaRow(eta: eta, unit: product.unit),
                  const SizedBox(height: 3),
                  Text(
                    product.nameAr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CurrencyFormatter.jod(product.displayPrice),
                              style: AppTextStyles.price.copyWith(fontSize: 14),
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

/// "⏱ 30–35 د · لتر": how long delivery takes, and the pack size.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.eta, required this.unit});

  final EtaRange? eta;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final hasUnit = unit != null && unit!.trim().isNotEmpty;
    if (eta == null && !hasUnit) return const SizedBox.shrink();
    return Row(
      children: [
        if (eta != null) ...[
          const Icon(Icons.schedule, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              etaRangeLabel(eta!, short: true),
              key: ProductCard.etaBadgeKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        if (eta != null && hasUnit)
          Text(' · ', style: AppTextStyles.caption.copyWith(fontSize: 11)),
        if (hasUnit)
          Flexible(
            child: Text(
              unit!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _DiscountTag extends StatelessWidget {
  const _DiscountTag({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ProductCard.discountTagKey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.discount,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'خصم $percent%',
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
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
          SnackBar(content: Text('الكمية المتوفرة من "${product.nameAr}" هي ${product.stockQuantity} فقط.')),
        );
      }
    }

    // Not in the cart yet: an outlined "add" pill.
    if (quantity == 0) {
      return InkWell(
        key: ProductCard.addKey,
        onTap: handleAdd,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 16, color: AppColors.accent),
              const SizedBox(width: 2),
              Text('أضف', style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    }

    // In the cart: a filled "− 1 +" pill.
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: () => ref.read(cartProvider.notifier).decrement(product),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: handleAdd),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 32,
        height: 34,
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
