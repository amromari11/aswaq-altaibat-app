import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../sponsors/domain/entities/sponsor_banner.dart';
import '../../../sponsors/presentation/widgets/sponsored_badge.dart';

/// Home banner carousel — serves both the store's own weekly-offer
/// promos and paid supplier placements (Pepsi, Almarai, Dettol, ...),
/// distinguished only by the "برعاية" badge on sponsored ones.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.banners,
    this.onBannerTap,
  });

  final List<SponsorBanner> banners;
  final ValueChanged<SponsorBanner>? onBannerTap;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 150,
            viewportFraction: 0.92,
            autoPlay: widget.banners.length > 1,
            autoPlayInterval: const Duration(seconds: 5),
            enlargeCenterPage: true,
            onPageChanged: (index, _) => setState(() => _activeIndex = index),
          ),
          items: widget.banners.map((banner) {
            return GestureDetector(
              onTap: () => widget.onBannerTap?.call(banner),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, _) => Container(color: AppColors.primaryLight),
                      errorWidget: (context, _, __) => Container(
                        color: AppColors.primaryLight,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.textMuted),
                      ),
                    ),
                    if (banner.isSponsored)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: SponsoredBadge(label: 'برعاية ${banner.sponsorName}'),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          AnimatedSmoothIndicator(
            activeIndex: _activeIndex,
            count: widget.banners.length,
            effect: const WormEffect(
              dotHeight: 6,
              dotWidth: 6,
              activeDotColor: AppColors.primary,
              dotColor: AppColors.border,
            ),
          ),
        ],
      ],
    );
  }
}
