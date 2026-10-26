import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/jordan_phone.dart';
import '../../../account/domain/entities/customer_info.dart';
import '../../../account/presentation/providers/customer_info_provider.dart';
import '../../../account/presentation/providers/profile_providers.dart';
import '../../../account/presentation/widgets/phone_entry_fields.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../data/repositories/checkout_repository.dart';
import '../providers/cart_provider.dart';
import '../providers/checkout_provider.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _notesController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneConfirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// True when the customer tapped "تغيير" on their remembered details. With
  /// nothing remembered the entry fields are always shown.
  bool _editingCustomer = false;
  bool _namePrefilled = false;

  @override
  void dispose() {
    _notesController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _phoneConfirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The Google account's display name, if signed in with one.
  String? _googleName() {
    final meta = ref.read(currentUserProvider)?.userMetadata ?? const {};
    final name = (meta['full_name'] ?? meta['name']) as String?;
    return (name == null || name.trim().isEmpty) ? null : name.trim();
  }

  /// Name + phone already known for this customer, so they don't retype them:
  /// what this device last ordered with, else a signed-in user's Google name
  /// plus the phone saved on their profile. Null if either piece is missing.
  CustomerInfo? _savedCustomer() {
    final remembered = ref.watch(customerInfoProvider).valueOrNull;
    if (remembered != null) return remembered;
    final phone = ref.watch(profilePhoneProvider).valueOrNull;
    final name = ref.watch(currentUserProvider) == null ? null : _googleName();
    if (name != null && phone != null) return CustomerInfo(name: name, phone: phone);
    return null;
  }

  Future<void> _confirmOrder({required CustomerInfo? saved, required bool entering}) async {
    final address = ref.read(selectedAddressProvider);
    final zone = ref.read(selectedZoneProvider);
    if (address == null || zone == null) {
      _showMessage('الرجاء اختيار عنوان التوصيل.');
      return;
    }
    if (ref.read(cartSubtotalProvider) < zone.minOrderJod) {
      _showMessage('الحد الأدنى للطلب في ${zone.nameAr} هو ${CurrencyFormatter.jod(zone.minOrderJod)}.');
      return;
    }

    // No account needed: either use what's remembered, or validate what was
    // typed (name, plus the phone entered twice — the phone isn't verified by
    // SMS, so the double entry is the guard against typos).
    final CustomerInfo customer;
    if (entering) {
      if (!_formKey.currentState!.validate()) return;
      customer = CustomerInfo(
        name: _nameController.text.trim(),
        phone: JordanPhone.normalize(_phoneController.text)!,
      );
    } else {
      customer = saved!;
    }

    final orderId = await ref.read(checkoutControllerProvider.notifier).placeOrder(
          customerName: customer.name,
          customerPhone: customer.phone,
          deliveryAddress: '${zone.nameAr} - ${address.details}',
          deliveryLat: address.latitude,
          deliveryLng: address.longitude,
          notes: _notesController.text,
          zoneId: zone.id,
          // A local-only (guest) address has no server row to reference.
          addressId: address.isPersisted ? address.id : null,
        );

    if (!mounted) return;

    if (orderId != null) {
      await ref.read(customerInfoProvider.notifier).remember(customer);
      // A signed-in customer's profile phone follows the number they just
      // ordered with. Best effort: the order is already placed, and the
      // profile column is unique, so a clash must not surface as an error.
      if (ref.read(currentUserProvider) != null && ref.read(profilePhoneProvider).valueOrNull != customer.phone) {
        try {
          await savePhone(ref, customer.phone);
        } catch (_) {}
      }
      if (!mounted) return;
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
    final isSignedIn = ref.watch(currentUserProvider) != null;
    final saved = _savedCustomer();
    final detailsLoading = ref.watch(customerInfoProvider).isLoading ||
        (isSignedIn && ref.watch(profilePhoneProvider).isLoading);
    final entering = !detailsLoading && (saved == null || _editingCustomer);
    final isSubmitting = checkoutState.isLoading;

    // Signed in with Google but no phone saved yet: start the name field from
    // the Google name (once, so we never overwrite what they've typed).
    if (entering && !_namePrefilled && _nameController.text.isEmpty) {
      _namePrefilled = true;
      final name = _googleName();
      if (name != null) _nameController.text = name;
    }

    ref.listen<AsyncValue<void>>(checkoutControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null) return;

      final String message;
      if (error is OutOfStockException) {
        final names = error.issues.map((issue) {
          return issue.availableQuantity == 0
              ? issue.product.nameAr
              : '${issue.product.nameAr} (متبقي ${issue.availableQuantity})';
        }).join('، ');
        message = 'تم تحديث سلتك حسب الكمية المتوفرة فعلياً: $names';
      } else if (error is OrderRejectedException) {
        message = _rejectionMessage(error.code);
      } else {
        message = 'تعذر إتمام الطلب. تحقق من الاتصال وحاول مرة أخرى.';
      }
      _showMessage(message);
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
            Text('بيانات التواصل', style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text(
              'سيتصل بك السائق على هذا الرقم عند التوصيل — لا نحتاج حساباً أو رمز تحقق.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            if (detailsLoading)
              const LinearProgressIndicator()
            else if (!entering)
              _SavedCustomerTile(
                name: saved!.name,
                phone: JordanPhone.toLocal(saved.phone),
                onChange: () => setState(() {
                  _editingCustomer = true;
                  _nameController.text = saved.name;
                  _phoneController.clear();
                  _phoneConfirmController.clear();
                }),
              )
            else ...[
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  final name = (value ?? '').trim();
                  if (name.isEmpty) return 'الرجاء إدخال اسمك.';
                  if (name.length < 2) return 'الاسم قصير جداً.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              PhoneEntryFields(
                phoneController: _phoneController,
                confirmController: _phoneConfirmController,
              ),
            ],
            if (!isSignedIn)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  // Optional: signing in saves addresses and carts across
                  // devices; nobody has to, to order.
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.account_circle_outlined, size: 18),
                  label: const Text('لديك حساب؟ سجّل الدخول بحساب Google (اختياري)'),
                ),
              ),
            const SizedBox(height: 12),
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
              onPressed: isSubmitting || items.isEmpty || belowMinimum || detailsLoading
                  ? null
                  : () => _confirmOrder(saved: saved, entering: entering),
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

class _SavedCustomerTile extends StatelessWidget {
  const _SavedCustomerTile({required this.name, required this.phone, required this.onChange});

  final String name;
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
          const Icon(Icons.person_outline, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyMedium),
                Text(phone, textDirection: TextDirection.ltr, style: AppTextStyles.caption),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('تغيير')),
        ],
      ),
    );
  }
}

/// Arabic text for the error codes `place_order` raises (backend 008).
String _rejectionMessage(String code) {
  switch (code) {
    case 'below_minimum':
      return 'قيمة الطلب أقل من الحد الأدنى لمنطقة التوصيل المختارة.';
    case 'out_of_stock':
    case 'insufficient_stock':
    case 'unknown_product':
      return 'بعض المنتجات لم تعد متوفرة بالكمية المطلوبة. راجع سلتك وحاول مرة أخرى.';
    case 'invalid_phone':
      return 'رقم الهاتف غير صحيح. أدخل رقماً أردنياً يبدأ بـ 077 أو 078 أو 079.';
    case 'invalid_name':
      return 'الرجاء إدخال اسمك (حرفان على الأقل).';
    case 'invalid_address':
      return 'الرجاء إدخال تفاصيل عنوان صحيحة.';
    case 'invalid_zone':
      return 'منطقة التوصيل المختارة لم تعد متاحة. اختر عنواناً آخر.';
    case 'too_many_orders':
      return 'تم تقديم عدة طلبات خلال وقت قصير. حاول مرة أخرى بعد قليل.';
    default:
      return 'تعذر إتمام الطلب. حاول مرة أخرى.';
  }
}
