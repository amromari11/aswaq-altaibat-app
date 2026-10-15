import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../cart/presentation/providers/cart_provider.dart';

/// Sticky bar pinned above the bottom nav once the cart has items, showing
/// either "أضف X دنانير إضافية لتوصيل مجاني" progress or, once the
/// threshold is met, a confirmed free-delivery state — then the item
/// count/subtotal and a button to open the cart.
class FloatingCartBar extends ConsumerWidget {
  const FloatingCartBar({super.key, required this.onViewCart});

  final VoidCallback onViewCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(cartItemCountProvider);
    if (itemCount == 0) return const SizedBox.shrink();

    final subtotal = ref.watch(cartSubtotalProvider);
    final remaining = ref.watch(freeDeliveryRemainingProvider);
    final qualifiesForFreeDelivery = remaining <= 0;
    final progress =
        (subtotal / AppConfig.freeDeliveryThresholdJod).clamp(0.0, 1.0);

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.border,
                color: qualifiesForFreeDelivery ? AppColors.success : AppColors.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              qualifiesForFreeDelivery
                  ? 'تهانينا! حصلت على توصيل مجاني 🎉'
                  : 'أضف ${CurrencyFormatter.jod(remaining)} إضافية لتوصيل مجاني',
              style: AppTextStyles.caption.copyWith(
                color: qualifiesForFreeDelivery ? AppColors.success : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$itemCount',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    CurrencyFormatter.jod(subtotal),
                    style: AppTextStyles.h3,
                  ),
                ),
                ElevatedButton(
                  onPressed: onViewCart,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('عرض السلة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
