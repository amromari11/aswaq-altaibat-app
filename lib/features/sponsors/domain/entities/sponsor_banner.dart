enum BannerPlacement { home, inCart }

BannerPlacement _placementFromString(String? value) {
  return value == 'in_cart' ? BannerPlacement.inCart : BannerPlacement.home;
}

/// Mirrors `sponsors_banners` (see `supabase/003_sponsors.sql` on the
/// backend). Covers both organic promo banners (weekly offers the store
/// itself runs) and paid sponsor placements — `sponsorName` is null for the
/// former, set for the latter, which is what the UI uses to decide whether
/// to show a "برعاية" (sponsored by) badge.
class SponsorBanner {
  const SponsorBanner({
    required this.id,
    required this.imageUrl,
    this.title,
    this.sponsorName,
    this.linkProductId,
    this.linkCategoryId,
    this.placement = BannerPlacement.home,
    this.displayOrder = 0,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? sponsorName;
  final String? linkProductId;
  final String? linkCategoryId;
  final BannerPlacement placement;
  final int displayOrder;

  bool get isSponsored => sponsorName != null && sponsorName!.isNotEmpty;

  factory SponsorBanner.fromJson(Map<String, dynamic> json) {
    return SponsorBanner(
      id: json['id'] as String,
      imageUrl: (json['image_url'] as String?) ?? '',
      title: json['title'] as String?,
      sponsorName: json['sponsor_name'] as String?,
      linkProductId: json['link_product_id'] as String?,
      linkCategoryId: json['link_category_id'] as String?,
      placement: _placementFromString(json['placement'] as String?),
      displayOrder: (json['display_order'] as int?) ?? 0,
    );
  }
}
