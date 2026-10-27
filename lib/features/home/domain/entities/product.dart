enum StockStatus { inStock, lowStock, outOfStock }

StockStatus _stockStatusFromString(String? value) {
  switch (value) {
    case 'low_stock':
      return StockStatus.lowStock;
    case 'out_of_stock':
      return StockStatus.outOfStock;
    case 'in_stock':
    default:
      return StockStatus.inStock;
  }
}

/// Mirrors the `products` table in `supabase/schema.sql` on the backend —
/// keep the two in sync when either changes.
class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.nameAr,
    required this.price,
    this.description,
    this.imageUrl,
    this.unit,
    this.discountPrice,
    this.stockQuantity = 0,
    this.stockStatus = StockStatus.inStock,
    this.isWeeklyOffer = false,
    this.isAppExclusive = false,
  });

  final String id;
  final String categoryId;
  final String name;
  final String nameAr;
  final String? description;
  final String? imageUrl;

  /// False for most products for now; the app then shows the category's picture instead.
  bool get hasOwnImage => imageUrl != null && imageUrl!.isNotEmpty;
  final String? unit;
  final double price;
  final double? discountPrice;
  final int stockQuantity;
  final StockStatus stockStatus;
  final bool isWeeklyOffer;
  final bool isAppExclusive;

  bool get hasDiscount => discountPrice != null && discountPrice! < price;

  double get displayPrice => hasDiscount ? discountPrice! : price;

  /// Rounded for badge display, e.g. "15% OFF".
  int get discountPercent {
    if (!hasDiscount || price == 0) return 0;
    return (((price - discountPrice!) / price) * 100).round();
  }

  bool get isOutOfStock => stockStatus == StockStatus.outOfStock;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: (json['name'] as String?) ?? '',
      nameAr: (json['name_ar'] as String?) ?? (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      unit: json['unit'] as String?,
      price: (json['price'] as num).toDouble(),
      discountPrice: (json['discount_price'] as num?)?.toDouble(),
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      stockStatus: _stockStatusFromString(json['stock_status'] as String?),
      isWeeklyOffer: (json['is_weekly_offer'] as bool?) ?? false,
      isAppExclusive: (json['is_app_exclusive'] as bool?) ?? false,
    );
  }
}
