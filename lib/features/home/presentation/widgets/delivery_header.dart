import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/brand_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../cart/presentation/providers/fulfillment_providers.dart';
import '../../../location/presentation/providers/delivery_eta_provider.dart';
import '../../../location/presentation/providers/location_providers.dart';

/// Top of Home: the logo, how fast we deliver, and where to.
///
///   [logo + rider]                         [account]
///   التوصيل خلال
///   30–35 دقيقة ⚡
///   📍 المنزل · الزرقاء ▾
class DeliveryHeader extends ConsumerWidget {
  const DeliveryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eta = ref.watch(deliveryEtaProvider);
    final address = ref.watch(selectedAddressProvider);
    final zone = ref.watch(selectedZoneProvider);
    final planner = ref.watch(slotPlannerProvider);
    final now = ref.watch(clockProvider)();
    final closed = planner != null && !planner.isOpenAt(now);
    final location = address == null ? 'حدد موقع التوصيل' : '${address.label} · ${zone?.nameAr ?? ''}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryLight, AppColors.canvas],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Lottie.network(
                  BrandAssets.fastDeliveryLottieUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.delivery_dining, color: AppColors.primary, size: 28),
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(child: BrandLogo(height: 40)),
              const Spacer(),
              _AccountButton(onTap: () => context.go('/account')),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'التوصيل خلال',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  eta == null ? 'أسرع ما يمكن' : etaRangeLabel(eta),
                  key: const ValueKey('delivery-eta'),
                  style: AppTextStyles.h1.copyWith(fontSize: 26, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.bolt, color: AppColors.accent, size: 26),
            ],
          ),
          if (closed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                key: const ValueKey('store-closed-chip'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'المتجر مغلق الآن — نفتح ${planner.settings.hoursLabel.split(' – ').first} ويمكنك جدولة طلبك',
                  style: AppTextStyles.caption.copyWith(color: AppColors.accentDark, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 2),
          InkWell(
            onTap: () => context.push('/addresses'),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'حسابي',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.person_outline, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
