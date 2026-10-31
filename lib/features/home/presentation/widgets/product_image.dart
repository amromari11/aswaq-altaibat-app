import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../categories/presentation/providers/category_image_provider.dart';
import '../../../categories/presentation/widgets/category_image.dart';
import '../../domain/entities/product.dart';

/// A product's picture on a white rounded tile.
///
/// With its own picture (the admin uploads these as white-background squares) it is shown whole.
/// Without one (most of the 11,000+ products for now) it shows its category's picture, framed on the
/// same white tile and marked "صورة توضيحية" so nobody mistakes it for the exact product.
class ProductImage extends ConsumerWidget {
  const ProductImage({super.key, required this.product, this.radius = 14});

  final Product product;
  final double radius;

  static const fallbackKey = ValueKey('product-image-fallback');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryUrl = ref.watch(categoryImageUrlProvider(product.categoryId));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: SizedBox.expand(
          child: !product.hasOwnImage
              ? _CategoryFallback(categoryUrl: categoryUrl)
              : CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  fit: BoxFit.contain,
                  memCacheWidth: 400,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: AppColors.primaryLight,
                    highlightColor: Colors.white,
                    child: const ColoredBox(color: Colors.white),
                  ),
                  // A picture that fails to load is no worse than having none.
                  errorWidget: (_, __, ___) => _CategoryFallback(categoryUrl: categoryUrl),
                ),
        ),
      ),
    );
  }
}

class _CategoryFallback extends StatelessWidget {
  const _CategoryFallback({required this.categoryUrl});

  final String? categoryUrl;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = categoryUrl != null && categoryUrl!.isNotEmpty;
    return Padding(
      key: ProductImage.fallbackKey,
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.tile),
            CategoryImage(imageUrl: categoryUrl, iconColor: AppColors.textMuted, cacheWidth: 300),
            if (hasPhoto)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'صورة توضيحية',
                    maxLines: 1,
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


/// A product's picture without the framing tile or the "illustrative" label —
/// for tiny uses (the cart bar). Its own picture, else its category's.
class ProductThumb extends ConsumerWidget {
  const ProductThumb({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryUrl = ref.watch(categoryImageUrlProvider(product.categoryId));
    return CategoryImage(
      imageUrl: product.hasOwnImage ? product.imageUrl : categoryUrl,
      iconColor: AppColors.textMuted,
      cacheWidth: 100,
    );
  }
}
