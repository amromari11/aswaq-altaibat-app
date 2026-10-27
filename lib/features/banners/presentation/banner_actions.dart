import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../categories/presentation/providers/selected_category_provider.dart';
import '../../home/presentation/providers/home_providers.dart';
import '../domain/entities/promo_banner.dart';

/// Opens an https link; returns whether it could be opened.
typedef LinkLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchExternally(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Carries out a tapped banner's action. Returns false when it couldn't (a
/// link that won't open, a product that no longer exists) so the caller can say so.
///
/// * category: filters Home to it (the shopper is already on Home);
/// * product: shows that product through Home's search - there is no product page yet;
/// * link: opens it outside the app (https only).
Future<bool> openBanner(WidgetRef ref, PromoBanner banner,
    {LinkLauncher launch = _launchExternally}) async {
  final id = banner.targetId;
  if (id == null || id.isEmpty) return false;

  switch (banner.targetType) {
    case BannerTargetType.none:
      return false;
    case BannerTargetType.category:
      ref.read(searchQueryProvider.notifier).state = '';
      ref.read(selectedCategoryProvider.notifier).state = id;
      return true;
    case BannerTargetType.product:
      final product = await ref.read(homeRepositoryProvider).fetchProduct(id);
      if (product == null) return false;
      ref.read(selectedCategoryProvider.notifier).state = null;
      ref.read(searchQueryProvider.notifier).state =
          product.nameAr.isNotEmpty ? product.nameAr : product.name;
      return true;
    case BannerTargetType.link:
      final uri = Uri.tryParse(id);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
      return launch(uri);
  }
}
