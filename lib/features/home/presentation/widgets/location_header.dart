import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../location/presentation/providers/location_providers.dart';

/// Delivery-location bar: shows the selected saved address's label and zone,
/// or a prompt to add one. Tapping opens the saved-addresses list.
class LocationHeader extends ConsumerWidget {
  const LocationHeader({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(selectedAddressProvider);
    final zone = ref.watch(selectedZoneProvider);
    final label = address == null ? 'الزرقاء - تحديد الموقع' : '${address.label} - ${zone?.nameAr ?? ''}';
    return InkWell(
      onTap: () => context.push('/addresses'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
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
