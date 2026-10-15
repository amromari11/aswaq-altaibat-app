import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import 'product_card.dart';

/// Non-scrolling grid meant to be embedded inside the home page's outer
/// scroll view (shrinkWrap + NeverScrollableScrollPhysics) so the whole
/// page scrolls as one surface instead of nesting independent scrollables.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products, this.onProductTap});

  final List<Product> products;
  final ValueChanged<Product>? onProductTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: () => onProductTap?.call(product),
        );
      },
    );
  }
}
