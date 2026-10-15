import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shared placeholder for tabs/pages not built out yet, so the bottom nav
/// is fully navigable from day one instead of 404-ing on four of its five
/// tabs.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, required this.message, this.icon = Icons.hourglass_empty});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
