/// Mirrors `promoted_products` (see `supabase/003_sponsors.sql`). A thin
/// join row: which product is promoted, in which slot, and whether it
/// carries a "مُوصى به" badge or a cross-sell placement in the cart.
class PromotedProduct {
  const PromotedProduct({
    required this.id,
    required this.productId,
    required this.sponsorName,
    this.slot = 'top_of_search',
    this.displayOrder = 0,
  });

  final String id;
  final String productId;
  final String sponsorName;
  final String slot;
  final int displayOrder;

  factory PromotedProduct.fromJson(Map<String, dynamic> json) {
    return PromotedProduct(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      sponsorName: (json['sponsor_name'] as String?) ?? '',
      slot: (json['slot'] as String?) ?? 'top_of_search',
      displayOrder: (json['display_order'] as int?) ?? 0,
    );
  }
}
