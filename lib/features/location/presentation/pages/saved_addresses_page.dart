import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/saved_address.dart';
import '../providers/location_providers.dart';

/// Lists saved delivery addresses. Pushed from Account and Home; when pushed
/// from checkout with `extra: true` ("pick mode") tapping a row selects it and
/// pops.
class SavedAddressesPage extends ConsumerWidget {
  const SavedAddressesPage({super.key, this.pickMode = false});

  final bool pickMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(savedAddressesProvider);
    final selected = ref.watch(selectedAddressProvider);

    return Scaffold(
      appBar: AppBar(title: Text(pickMode ? 'اختر عنوان التوصيل' : 'عناوين التوصيل')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/address-form'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('إضافة عنوان'),
      ),
      body: addresses.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return _AddressCard(
                  address: address,
                  isSelected: address.id == selected?.id,
                  onTap: pickMode
                      ? () {
                          ref.read(selectedAddressIdProvider.notifier).state = address.id;
                          context.pop();
                        }
                      : () => context.push('/address-form', extra: address),
                );
              },
            ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address, required this.isSelected, required this.onTap});

  final SavedAddress address;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(zoneByIdProvider(address.zoneId));
    final notifier = ref.read(savedAddressesProvider.notifier);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(address.label, style: AppTextStyles.h3),
                  if (address.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('افتراضي', style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
                    ),
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'default') notifier.setDefault(address.id);
                      if (value == 'delete') notifier.remove(address.id);
                    },
                    itemBuilder: (_) => [
                      if (!address.isDefault) const PopupMenuItem(value: 'default', child: Text('تعيين كافتراضي')),
                      const PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [if (zone != null) zone.nameAr, address.details].join(' - '),
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              if (zone != null) ...[
                const SizedBox(height: 8),
                Text(
                  'التوصيل ${CurrencyFormatter.jod(zone.deliveryFeeJod)} • الحد الأدنى ${CurrencyFormatter.jod(zone.minOrderJod)} • ~${zone.etaMinutes} دقيقة',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
              if (address.hasPin)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('تم تحديد الموقع على الخريطة', style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_location_alt_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('لا توجد عناوين محفوظة', style: AppTextStyles.h3),
            const SizedBox(height: 6),
            Text(
              'أضف عنوانك لتسريع الطلب ومعرفة رسوم التوصيل.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
