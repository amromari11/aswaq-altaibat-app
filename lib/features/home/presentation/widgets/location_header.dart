import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

/// "الزرقاء - تحديد الموقع" bar. Location selection itself (geolocation /
/// address picker) isn't wired up yet — this is the visual shell the next
/// pass hooks a real location source into.
class LocationHeader extends StatelessWidget {
  const LocationHeader({
    super.key,
    this.locationLabel = 'الزرقاء',
    this.onTap,
  });

  final String locationLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(
              '$locationLabel - تحديد الموقع',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
