import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';

/// A category's picture: shimmer while loading, and the grocery icon when the
/// category has no picture or it fails to load (offline, deleted file).
class CategoryImage extends StatelessWidget {
  const CategoryImage({
    super.key,
    required this.imageUrl,
    this.iconColor = AppColors.primary,
    this.cacheWidth = 300,
  });

  final String? imageUrl;
  final Color iconColor;

  /// Decoded width in px; keeps 600px source images light in memory.
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return _icon();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.primaryLight,
        highlightColor: Colors.white,
        child: const ColoredBox(color: Colors.white),
      ),
      errorWidget: (_, __, ___) => _icon(),
    );
  }

  Widget _icon() => Center(child: Icon(Icons.local_grocery_store_outlined, color: iconColor));
}
