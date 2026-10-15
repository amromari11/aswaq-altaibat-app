import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import 'product_card.dart';

/// Horizontal "Order Again" carousel for fast re-ordering past purchases.
class OrderAgainRow extends StatelessWidget {
  const OrderAgainRow({super.key, required this.products, this.onProductTap});

  final List<Product> products;
  final ValueChanged<Product>? onProductTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: 140,
            child: ProductCard(
              product: product,
              onTap: () => onProductTap?.call(product),
            ),
          );
        },
      ),
    );
  }
}
