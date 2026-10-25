import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../providers/cart_provider.dart';
import '../providers/checkout_provider.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmOrder() async {
    final address = ref.read(selectedAddressProvider);
    final zone = ref.read(selectedZoneProvider);
    if (address == null || zone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار عنوان التوصيل.')),
      );
      return;
    }
    if (ref.read(cartSubtotalProvider) < zone.minOrderJod) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الحد الأدنى للطلب في ${zone.nameAr} هو ${CurrencyFormatter.jod(zone.minOrderJod)}.')),
      );
      return;
    }

    final orderId = await ref.read(checkoutControllerProvider.notifier).placeOrder(
          deliveryAddress: '${zone.nameAr} - ${address.details}',
          deliveryLat: address.latitude,
          deliveryLng: address.longitude,
          notes: _notesController.text,
          deliveryFee: zone.deliveryFeeJod,
          zoneId: zone.id,
          // A local-only (guest) address has no server row to reference.
          addressId: address.isPersisted ? address.id : null,
        );

    if (!mounted) return;

    if (orderId != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
          title: const Text('تم تأكيد طلبك', textAlign: TextAlign.center),
          content: Text(
            'شكراً لطلبك من أسواق الطيبات! سيتم التواصل معك لتأكيد التوصيل.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسناً'),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartItemsListProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final remaining = ref.watch(freeDeliveryRemainingProvider);
    final address = ref.watch(selectedAddressProvider);
    final zone = ref.watch(selectedZoneProvider);
    final deliveryFee = remaining <= 0 ? 0.0 : (zone?.deliveryFeeJod ?? AppConfig.deliveryFeeJod);
    final belowMinimum = zone != null && subtotal < zone.minOrderJod;
    final total = subtotal + deliveryFee;
    final checkoutState = ref.watch(checkoutControllerProvider);
    final isSubmitting = checkoutState.isLoading;

    ref.listen<AsyncValue<void>>(checkoutControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null) return;

      final String message;
      if (error is NotSignedInException) {
        message = 'الرجاء تسجيل الدخول لإتمام الطلب.';
      } else if (error is OutOfStockException) {
        final names = error.issues.map((issue) {
          return issue.availableQuantity == 0
              ? issue.product.nameAr
              : '${issue.product.nameAr} (متبقي ${issue.availableQuantity})';
        }).join('، ');
        message = 'تم تحديث سلتك حسب الكمية المتوفرة فعلياً: $names';
      } else {
        message = 'تعذر إتمام الطلب. حاول مرة أخرى.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الطلب')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('عنوان التوصيل', style: AppTextStyles.h3),
            const SizedBox(height: 10),
            _AddressSelector(
              onChange: () => context.push('/addresses', extra: true),
              onAdd: () => context.push('/address-form'),
              label: address?.label,
              subtitle: address == null ? null : '${zone?.nameAr ?? ''} - ${address.details}',
              eta: zone?.etaMinutes,
            ),
            if (belowMinimum)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'الحد الأدنى للطلب في ${zone.nameAr} هو ${CurrencyFormatter.jod(zone.minOrderJod)}.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                ),
              ),
            const SizedBox(height: 20),
            Text('ملاحظات (اختياري)', style: AppTextStyles.h3),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'مثال: الرجاء الاتصال عند الوصول'),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'الدفع عند الاستلام',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _SummaryRow(label: 'عدد المنتجات', value: '${items.length}'),
                  const SizedBox(height: 8),
                  _SummaryRow(label: 'المجموع الفرعي', value: CurrencyFormatter.jod(subtotal)),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'رسوم التوصيل',
                    value: deliveryFee == 0 ? 'مجاني' : CurrencyFormatter.jod(deliveryFee),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: AppColors.border),
                  ),
                  _SummaryRow(
                    label: 'الإجمالي',
                    value: CurrencyFormatter.jod(total),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isSubmitting || items.isEmpty || belowMinimum ? null : _confirmOrder,
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('تأكيد الطلب'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? AppTextStyles.h3.copyWith(color: AppColors.primary)
        : AppTextStyles.body.copyWith(color: AppColors.textSecondary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _AddressSelector extends StatelessWidget {
  const _AddressSelector({
    required this.onChange,
    required this.onAdd,
    required this.label,
    required this.subtitle,
    required this.eta,
  });

  final VoidCallback onChange;
  final VoidCallback onAdd;
  final String? label;
  final String? subtitle;
  final int? eta;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('إضافة عنوان توصيل'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size.fromHeight(48),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label!, style: AppTextStyles.bodyMedium),
                Text(subtitle ?? '', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                if (eta != null)
                  Text('الوقت المتوقع ~$eta دقيقة', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('تغيير')),
        ],
      ),
    );
  }
}
