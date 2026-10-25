import 'package:flutter/material.dart';

import '../../../../core/utils/jordan_phone.dart';

/// Phone number + "confirm phone number" fields with validators, for use
/// inside a [Form]. Replaces OTP verification: the number must be a valid
/// Jordanian mobile and both entries must match. Paste is disabled on the
/// confirmation field so it's actually typed twice.
class PhoneEntryFields extends StatelessWidget {
  const PhoneEntryFields({
    super.key,
    required this.phoneController,
    required this.confirmController,
  });

  final TextEditingController phoneController;
  final TextEditingController confirmController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'رقم الهاتف',
            hintText: '07XX XXX XXX',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'الرجاء إدخال رقم الهاتف.';
            if (JordanPhone.normalize(value) == null) {
              return 'رقم غير صحيح. أدخل رقماً أردنياً يبدأ بـ 077 أو 078 أو 079.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: confirmController,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          enableInteractiveSelection: false, // no paste: make them type it again
          decoration: const InputDecoration(
            labelText: 'تأكيد رقم الهاتف',
            hintText: 'أعد إدخال الرقم',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'الرجاء إعادة إدخال رقم الهاتف.';
            final first = JordanPhone.normalize(phoneController.text);
            if (first == null || JordanPhone.normalize(value) != first) {
              return 'الرقمان غير متطابقين.';
            }
            return null;
          },
        ),
      ],
    );
  }
}
