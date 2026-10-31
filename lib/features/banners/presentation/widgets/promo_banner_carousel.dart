import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/promo_banner.dart';

/// Auto-scrolling promo carousel for the top of Home: cached images, a title
/// over a soft gradient, page dots, and a tap callback for tappable banners.
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key, required this.banners, this.onBannerTap});

  final List<PromoBanner> banners;
  final ValueChanged<PromoBanner>? onBannerTap;

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    // Tied to the list so a refreshed list with fewer banners can't leave the dots out of range.
    final active = _activeIndex.clamp(0, banners.length - 1);

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: banners.length,
          options: CarouselOptions(
            height: 172,
            viewportFraction: 0.92,
            autoPlay: banners.length > 1,
            // No endless looping: the slider would clone a lone banner, and keeping the pages
            // alive (below) would grow without bound. Auto-play wraps back to the first page.
            enableInfiniteScroll: false,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayAnimationDuration: const Duration(milliseconds: 700),
            enlargeCenterPage: true,
            onPageChanged: (index, _) => setState(() => _activeIndex = index),
          ),
          itemBuilder: (context, index, _) => _KeepAlive(
            child: _BannerCard(
              banner: banners[index],
              onTap:
                  banners[index].isTappable ? () => widget.onBannerTap?.call(banners[index]) : null,
            ),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 8),
          AnimatedSmoothIndicator(
            activeIndex: active,
            count: banners.length,
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

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, this.onTap});

  final PromoBanner banner;
  final VoidCallback? onTap;

  static const ctaKey = ValueKey('banner-cta');

  @override
  Widget build(BuildContext context) {
    final title = banner.title;
    return Semantics(
      button: onTap != null,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, __) => const ColoredBox(color: AppColors.primaryLight),
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: AppColors.primaryLight,
                    child: Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
                  ),
                ),
                if (title != null) ...[
                  // Darkens the side the words sit on, so they read on any photo.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [AppColors.primaryDark.withValues(alpha: 0.82), Colors.transparent],
                        stops: const [0.0, 0.85],
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: FractionallySizedBox(
                        widthFactor: 0.62,
                        // A very large system font scales the words down rather than overflowing.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: SizedBox(
                            width: 240,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.h2.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                                if (onTap != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    key: ctaKey,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'تسوّق الآن',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps a page's picture alive while it is scrolled away. On Flutter web a recycled page
/// re-creates its image element, which came back black or blank on later passes.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
