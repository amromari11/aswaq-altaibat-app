import 'package:aswaq_altaibat/core/utils/jordan_phone.dart';
import 'package:aswaq_altaibat/features/account/presentation/widgets/phone_entry_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JordanPhone.normalize', () {
    test('accepts the common ways customers type a mobile number', () {
      for (final input in ['0791234567', '791234567', '+962791234567', '00962791234567', '079 123 4567', '078-123-4567']) {
        expect(JordanPhone.normalize(input), isNotNull, reason: input);
      }
      expect(JordanPhone.normalize('0791234567'), '+962791234567');
      expect(JordanPhone.normalize('0771234567'), '+962771234567');
    });

    test('rejects landlines, wrong prefixes and wrong lengths', () {
      for (final input in ['', '065123456', '0761234567', '079123456', '07912345678', '+963791234567', 'abc']) {
        expect(JordanPhone.normalize(input), isNull, reason: input);
      }
    });

    test('toLocal formats back the way customers write it', () {
      expect(JordanPhone.toLocal('+962791234567'), '0791234567');
    });
  });

  group('PhoneEntryFields', () {
    Future<GlobalKey<FormState>> pump(WidgetTester tester, String phone, String confirm) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: PhoneEntryFields(
              phoneController: TextEditingController(text: phone),
              confirmController: TextEditingController(text: confirm),
            ),
          ),
        ),
      ));
      return key;
    }

    testWidgets('same number in different formats passes', (tester) async {
      final key = await pump(tester, '0791234567', '+962 79 123 4567');
      expect(key.currentState!.validate(), isTrue);
    });

    testWidgets('mismatched numbers fail with a mismatch message', (tester) async {
      final key = await pump(tester, '0791234567', '0791234568');
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('الرقمان غير متطابقين.'), findsOneWidget);
    });

    testWidgets('invalid number fails with a format message', (tester) async {
      final key = await pump(tester, '065123456', '065123456');
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.textContaining('رقم غير صحيح'), findsOneWidget);
    });
  });
}
