import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The Aswaq Al-Tayyibat logo (red cart + Arabic name + ALTAYEBAT).
///
/// The picture is `assets/images/logo.png`; if it can't be loaded the shop's
/// name is shown as text instead, so a screen never ends up without branding.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 34});

  static const asset = 'assets/images/logo.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'أسواق الطيبات',
      errorBuilder: (_, __, ___) => Text(
        'أسواق الطيبات',
        style: AppTextStyles.h3.copyWith(color: AppColors.primary, fontSize: height * 0.55),
      ),
    );
  }
}
