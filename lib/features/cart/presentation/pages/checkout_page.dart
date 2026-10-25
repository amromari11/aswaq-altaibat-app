import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/jordan_phone.dart';
import '../../../account/data/repositories/profile_repository.dart';
import '../../../account/presentation/providers/profile_providers.dart';
import '../../../account/presentation/widgets/phone_entry_fields.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
  final _phoneController = TextEditingController();
  final _phoneConfirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// True when the customer tapped "تغيير" on their saved phone. A customer
  /// with no saved phone always sees the entry fields.
  bool _changingPhone = false;
  bool _savingPhone = false;

  @override
  void dispose() {
    _notesController.dispose();
    _phoneController.dispose();
    _phoneConfirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Saves a newly entered phone to the profile before the order is placed.
  /// Returns false (after telling the user why) if the order shouldn't go
  /// ahead. Without a real session (the debug mock sign-in) there's nowhere
  /// to save it; placeOrder then reports "sign in" as before.
  Future<bool> _savePhoneIfEntered({required bool entering}) async {
    if (!entering) return true;
    if (!_formKey.currentState!.validate()) return false;
    final phone = JordanPhone.normalize(_phoneController.text)!;
    if (ref.read(currentUserProvider) == null) return true;

    setState(() => _savingPhone = true);
    try {
      await savePhone(ref, phone);
      if (mounted) setState(() => _changingPhone = false);
      return true;
    } on PhoneTakenException {
      _showMessage('رقم الهاتف هذا مسجل لحساب آخر. أدخل رقماً مختلفاً.');
      return false;
    } catch (_) {
      _showMessage('تعذر حفظ رقم الهاتف. تحقق من الاتصال وحاول مرة أخرى.');
      return false;
    } finally {
      if (mounted) setState(() => _savingPhone = false);
    }
  }

  Future<void> _confirmOrder({required bool enteringPhone}) async {
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

    // Guests fill in everything first; sign-in is only asked for now, at
    // the very end. The login page is pushed on top of this one, so this
    // page's state (selected address, typed phone) is still here when
    // main.dart's sign-in listener pops back to it.
    final isSignedIn = ref.read(currentUserProvider) != null || ref.read(isMockSignedInProvider);
    if (!isSignedIn) {
      if (enteringPhone && !_formKey.currentState!.validate()) return;
      ref.read(pendingRedirectProvider.notifier).state = '/checkout';
      ref.read(resumeCheckoutAfterSignInProvider.notifier).state = true;
      context.push('/login');
      return;
    }

    if (!await _savePhoneIfEntered(entering: enteringPhone)) return;
    if (!mounted) return;

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
    final phoneAsync = ref.watch(profilePhoneProvider);
    final savedPhone = phoneAsync.valueOrNull;
    final enteringPhone = !phoneAsync.isLoading && (savedPhone == null || _changingPhone);
    final isSubmitting = checkoutState.isLoading || _savingPhone;

    // Back from sign-in that this page's confirm button asked for: finish
    // the order with what the customer already entered, instead of making
    // them tap "تأكيد الطلب" a second time. Runs after the frame so
    // main.dart's listener has popped the login page first. The phone they
    // typed as a guest is the latest one they confirmed, so it's saved to
    // the account even if the account already had a different number.
    ref.listen<User?>(currentUserProvider, (previous, next) {
      if (previous != null || next == null) return;
      if (!ref.read(resumeCheckoutAfterSignInProvider)) return;
      ref.read(resumeCheckoutAfterSignInProvider.notifier).state = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _showMessage('تم تسجيل الدخول — جارٍ تأكيد طلبك...');
        // main.dart started merging the guest cart/addresses into the
        // account; wait for that before ordering (see hydrationDone).
        await Future.wait([
          ref.read(cartProvider.notifier).hydrationDone,
          ref.read(savedAddressesProvider.notifier).hydrationDone,
        ]);
        if (!mounted) return;
        await _confirmOrder(enteringPhone: _phoneController.text.trim().isNotEmpty);
      });
    });

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
            Text('رقم الهاتف', style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text(
              'سيتصل بك السائق على هذا الرقم عند التوصيل.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            if (phoneAsync.isLoading)
              const LinearProgressIndicator()
            else if (!enteringPhone)
              _SavedPhoneTile(
                phone: JordanPhone.toLocal(savedPhone!),
                onChange: () => setState(() {
                  _changingPhone = true;
                  _phoneController.clear();
                  _phoneConfirmController.clear();
                }),
              )
            else
              PhoneEntryFields(
                phoneController: _phoneController,
                confirmController: _phoneConfirmController,
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
              onPressed: isSubmitting || items.isEmpty || belowMinimum || phoneAsync.isLoading
                  ? null
                  : () => _confirmOrder(enteringPhone: enteringPhone),
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

class _SavedPhoneTile extends StatelessWidget {
  const _SavedPhoneTile({required this.phone, required this.onChange});

  final String phone;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(phone, textDirection: TextDirection.ltr, textAlign: TextAlign.start, style: AppTextStyles.bodyMedium),
          ),
          TextButton(onPressed: onChange, child: const Text('تغيير')),
        ],
      ),
    );
  }
}
