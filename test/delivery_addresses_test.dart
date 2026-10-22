import 'package:aswaq_altaibat/features/cart/domain/entities/cart_item.dart';
import 'package:aswaq_altaibat/features/cart/presentation/pages/checkout_page.dart';
import 'package:aswaq_altaibat/features/cart/presentation/providers/cart_provider.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/product.dart';
import 'package:aswaq_altaibat/features/location/domain/entities/saved_address.dart';
import 'package:aswaq_altaibat/features/location/presentation/providers/location_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SavedAddress _address(String id, {String zoneId = 'new_zarqa', bool isDefault = false}) =>
    SavedAddress(id: id, label: 'L$id', zoneId: zoneId, details: 'details', isDefault: isDefault);

void main() {
  group('SavedAddressesNotifier', () {
    test('first address becomes default; flagging another moves the default', () {
      final n = SavedAddressesNotifier();
      n.upsert(_address('a'));
      expect(n.state.single.isDefault, isTrue);

      n.upsert(_address('b', isDefault: true));
      expect(n.state.where((a) => a.isDefault).map((a) => a.id), ['b']);
    });

    test('removing the default promotes another address', () {
      final n = SavedAddressesNotifier()
        ..upsert(_address('a'))
        ..upsert(_address('b'));
      n.remove('a');
      expect(n.state.single.id, 'b');
      expect(n.state.single.isDefault, isTrue);
    });

    test('upsert with an existing id replaces instead of duplicating', () {
      final n = SavedAddressesNotifier()..upsert(_address('a'));
      n.upsert(_address('a').copyWith(label: 'edited'));
      expect(n.state, hasLength(1));
      expect(n.state.single.label, 'edited');
    });
  });

  group('CheckoutPage with zones', () {
    const product = Product(id: 'p1', categoryId: 'c', name: 'n', nameAr: 'منتج', price: 2);

    Future<void> pump(WidgetTester tester, {required double subtotal, List<SavedAddress> addresses = const []}) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final notifier = SavedAddressesNotifier();
      for (final a in addresses) {
        notifier.upsert(a);
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedAddressesProvider.overrideWith((ref) => notifier),
            cartItemsListProvider.overrideWithValue([const CartItem(product: product, quantity: 1)]),
            cartSubtotalProvider.overrideWithValue(subtotal),
            freeDeliveryRemainingProvider.overrideWithValue(20 - subtotal),
          ],
          child: const MaterialApp(home: CheckoutPage()),
        ),
      );
    }

    testWidgets('no address: shows add-address prompt', (tester) async {
      await pump(tester, subtotal: 10);
      expect(find.text('إضافة عنوان توصيل'), findsOneWidget);
    });

    testWidgets('below the zone minimum: shows warning and disables confirm', (tester) async {
      await pump(tester, subtotal: 2, addresses: [_address('a')]); // new_zarqa min 8
      expect(find.textContaining('الحد الأدنى للطلب'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('meets the minimum: confirm enabled, zone fee 1.500 shown', (tester) async {
      await pump(tester, subtotal: 10, addresses: [_address('a')]);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
      expect(find.textContaining('1.500'), findsWidgets);
    });
  });
}
