/// What a banner opens when tapped.
enum BannerTargetType { none, category, product, link }

BannerTargetType _targetFromString(String? value) {
  switch (value) {
    case 'category':
      return BannerTargetType.category;
    case 'product':
      return BannerTargetType.product;
    case 'link':
      return BannerTargetType.link;
    default:
      return BannerTargetType.none;
  }
}

/// A Home-carousel banner (`banners` table, migration 013 on the backend).
class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.imageUrl,
    this.title,
    this.targetType = BannerTargetType.none,
    this.targetId,
    this.displayOrder = 0,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final BannerTargetType targetType;

  /// Category or product id, or the https link, depending on [targetType].
  final String? targetId;
  final int displayOrder;

  bool get isTappable => targetType != BannerTargetType.none && (targetId?.isNotEmpty ?? false);

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String?)?.trim();
    return PromoBanner(
      id: json['id'] as String,
      imageUrl: (json['image_url'] as String?) ?? '',
      title: (title == null || title.isEmpty) ? null : title,
      targetType: _targetFromString(json['target_type'] as String?),
      targetId: json['target_id'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}
