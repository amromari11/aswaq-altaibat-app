import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/brand_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Compact branding strip pinned above the curved navy hero header: a
/// small looping delivery animation beside the store name.
///
/// Deliberately its own white strip rather than sitting inside the navy
/// hero below it — navy brand-colored text on the navy header would be
/// illegible, so this strip is what gives "أسواق الطيبات" proper
/// navy-on-white contrast while the hero header keeps its own look.
class HomeBrandBar extends StatelessWidget {
  const HomeBrandBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Lottie.network(
              BrandAssets.fastDeliveryLottieUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.local_shipping_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'أسواق الطيبات',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3.copyWith(color: AppColors.primary, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
