import 'package:aswaq_altaibat/core/supabase/supabase_providers.dart';
import 'package:aswaq_altaibat/features/account/data/repositories/profile_repository.dart';
import 'package:aswaq_altaibat/features/account/presentation/providers/customer_info_provider.dart';
import 'package:aswaq_altaibat/features/account/presentation/providers/profile_providers.dart';
import 'package:aswaq_altaibat/features/cart/data/repositories/cart_repository.dart';
import 'package:aswaq_altaibat/features/cart/data/repositories/checkout_repository.dart';
import 'package:aswaq_altaibat/features/cart/domain/entities/cart_item.dart';
import 'package:aswaq_altaibat/features/cart/domain/entities/fulfillment.dart';
import 'package:aswaq_altaibat/features/cart/presentation/pages/checkout_page.dart';
import 'package:aswaq_altaibat/features/cart/presentation/providers/cart_provider.dart';
import 'package:aswaq_altaibat/features/cart/presentation/providers/checkout_provider.dart';
import 'package:aswaq_altaibat/features/cart/presentation/providers/fulfillment_providers.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/product.dart';
import 'package:aswaq_altaibat/features/location/domain/entities/delivery_zone.dart';
import 'package:aswaq_altaibat/features/orders/data/local/my_orders_store.dart';
import 'package:aswaq_altaibat/features/location/domain/entities/saved_address.dart';
import 'package:aswaq_altaibat/features/location/presentation/providers/location_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

const _zone = DeliveryZone(
  id: 'c3d625fe-22d7-44e6-bb43-b0ac1318840c',
  nameAr: 'الزرقاء الجديدة',
  deliveryFeeJod: 1.5,
  minOrderJod: 7,
  etaMinutes: 35,
);

const _product = Product(id: 'p1', categoryId: 'c', name: 'n', nameAr: 'منتج', price: 2);

final _address = SavedAddress(id: 'a1', label: 'المنزل', zoneId: _zone.id, details: 'شارع الجيش', isDefault: true);

const _store = StoreSettings(
  branchName: 'أسواق الطيبات - فرع الزرقاء',
  branchAddress: 'الزرقاء، شارع الملك عبدالله',
  branchPhone: '0791112222',
  latitude: 32.073313,
  longitude: 36.095312,
  opensAtMinutes: 8 * 60,
  closesAtMinutes: 23 * 60,
);

/// Monday 2 Nov 2026, 10:30 in Amman (UTC+3): open, first slot 12:00.
final _morning = DateTime.utc(2026, 11, 2, 7, 30);

/// 02:00 in Amman: closed.
final _night = DateTime.utc(2026, 11, 1, 23, 0);

const _googleUser = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {'full_name': 'Google Person'},
  aud: 'authenticated',
  createdAt: '2026-10-25T00:00:00Z',
);

/// Records what the app asks the database to do and plays its answers.
class _FakeCheckoutRepository implements CheckoutRepository {
  final orders = <Map<String, Object?>>[];
  String? rejectWith;

  @override
  Future<List<StockIssue>> checkStock(List<CartItem> items) async => const [];

  @override
  Future<String> placeOrder({
    required String customerName,
    required String customerPhone,
    required List<CartItem> items,
    String? deliveryAddress,
    String? zoneId,
    OrderType orderType = OrderType.delivery,
    DateTime? scheduledTime,
    String? addressId,
    double? deliveryLat,
    double? deliveryLng,
    String? notes,
    String? trackingToken,
  }) async {
    if (rejectWith != null) throw OrderRejectedException(rejectWith!);
    orders.add({
      'name': customerName,
      'phone': customerPhone,
      'zoneId': zoneId,
      'addressId': addressId,
      'address': deliveryAddress,
      'quantity': items.single.quantity,
      'token': trackingToken,
      'type': orderType,
      'scheduled': scheduledTime,
    });
    return 'order-1';
  }
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository([this.phone]);

  String? phone;
  final saved = <String>[];

  @override
  Future<String?> fetchPhone(String userId) async => phone;

  @override
  Future<void> updatePhone(String userId, String newPhone) async {
    saved.add(newPhone);
    phone = newPhone;
  }
}

/// Addresses preloaded into state, without going through the sync-to-server
/// path that a real save takes.
class _PresetAddresses extends SavedAddressesNotifier {
  _PresetAddresses(super.ref, List<SavedAddress> addresses) {
    state = addresses;
  }
}

class _FakeCartRepository implements CartRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  late _FakeCheckoutRepository orders;
  late GoRouter router;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orders = _FakeCheckoutRepository();
  });

  /// Mounts checkout inside a router (so push/go work) with fakes in place of
  /// Supabase. [subtotal] defaults to clearing the zone minimum.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    double subtotal = 10,
    SavedAddress? address,
    User? user,
    _FakeProfileRepository? profiles,
    StoreSettings? settings,
    DateTime? now,
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(path: '/checkout', builder: (_, __) => const CheckoutPage()),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LOGIN PAGE'))),
        GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME PAGE'))),
        GoRoute(
          path: '/order/:id',
          builder: (_, state) => Scaffold(body: Text('TRACKING ${state.pathParameters['id']} ${state.uri.queryParameters['t']}')),
        ),
        GoRoute(path: '/addresses', builder: (_, __) => const Scaffold(body: Text('ADDRESSES'))),
        GoRoute(path: '/address-form', builder: (_, __) => const Scaffold(body: Text('ADDRESS FORM'))),
      ],
    );
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(user),
      checkoutRepositoryProvider.overrideWithValue(orders),
      profileRepositoryProvider.overrideWithValue(profiles ?? _FakeProfileRepository()),
      cartRepositoryProvider.overrideWithValue(_FakeCartRepository()),
      zonesProvider.overrideWith((ref) async => const [_zone]),
      savedAddressesProvider.overrideWith((ref) => _PresetAddresses(ref, [if (address != null) address])),
      cartItemsListProvider.overrideWithValue([const CartItem(product: _product, quantity: 3)]),
      cartSubtotalProvider.overrideWithValue(subtotal),
      freeDeliveryRemainingProvider.overrideWithValue(20 - subtotal),
      // No store settings = a server without pickup/scheduling: delivery now only, as before.
      storeSettingsProvider.overrideWith((ref) async => settings),
      clockProvider.overrideWithValue(() => now ?? _morning),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> fillCustomer(WidgetTester tester, {String name = 'سالم أحمد', String phone = '0791234567', String? confirm}) async {
    await tester.enterText(find.byType(TextFormField).at(0), name);
    await tester.enterText(find.byType(TextFormField).at(1), phone);
    await tester.enterText(find.byType(TextFormField).at(2), confirm ?? phone);
  }

  Future<void> tapConfirm(WidgetTester tester) async {
    await tester.tap(find.text('تأكيد الطلب'));
    await tester.pumpAndSettle();
  }

  group('zones and address', () {
    testWidgets('no address: shows the add-address prompt', (tester) async {
      await pump(tester);
      expect(find.text('إضافة عنوان توصيل'), findsOneWidget);
    });

    testWidgets('below the zone minimum: warning shown and confirm disabled', (tester) async {
      await pump(tester, subtotal: 2, address: _address);
      expect(find.textContaining('الحد الأدنى للطلب'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    });

    testWidgets('meets the minimum: confirm enabled and the zone fee is shown', (tester) async {
      await pump(tester, address: _address);
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
      expect(find.textContaining('1.500'), findsWidgets);
    });
  });

  group('guest checkout (no account)', () {
    testWidgets('asks for name + phone twice, with an optional Google link', (tester) async {
      await pump(tester, address: _address);
      expect(find.text('الاسم الكامل'), findsOneWidget);
      expect(find.text('رقم الهاتف'), findsOneWidget);
      expect(find.text('تأكيد رقم الهاتف'), findsOneWidget);
      expect(find.textContaining('اختياري'), findsWidgets);
      expect(find.textContaining('سجّل الدخول بحساب Google'), findsOneWidget);
    });

    testWidgets('places the order with no sign-in: server gets the name and E.164 phone', (tester) async {
      await pump(tester, address: _address);
      await fillCustomer(tester, phone: '079 123 4567', confirm: '0791234567');
      await tapConfirm(tester);

      expect(find.text('LOGIN PAGE'), findsNothing);
      expect(orders.orders, hasLength(1));
      expect(orders.orders.single['name'], 'سالم أحمد');
      expect(orders.orders.single['phone'], '+962791234567');
      expect(orders.orders.single['zoneId'], _zone.id);
      expect(orders.orders.single['addressId'], isNull, reason: 'a guest address has no server row');
      expect(orders.orders.single['address'], contains('شارع الجيش'));
      // Straight to live tracking for THIS order — no static confirmation.
      expect(find.text('تم تأكيد طلبك'), findsNothing);
      final token = orders.orders.single['token'] as String;
      expect(token, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(find.text('TRACKING order-1 $token'), findsOneWidget);
    });

    testWidgets('remembers the order on this device so it can be found again', (tester) async {
      final container = await pump(tester, address: _address);
      await fillCustomer(tester);
      await tapConfirm(tester);

      final refs = container.read(myOrderRefsProvider).valueOrNull!;
      expect(refs.single.id, 'order-1');
      expect(refs.single.token, orders.orders.single['token']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('my_orders'), contains('order-1'));
    });

    testWidgets('remembers the details on the device for next time', (tester) async {
      final container = await pump(tester, address: _address);
      await fillCustomer(tester);
      await tapConfirm(tester);

      final saved = container.read(customerInfoProvider).valueOrNull;
      expect(saved?.name, 'سالم أحمد');
      expect(saved?.phone, '+962791234567');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('customer_phone'), '+962791234567');
    });

    testWidgets('mismatched phone entries block the order', (tester) async {
      await pump(tester, address: _address);
      await fillCustomer(tester, phone: '0791234567', confirm: '0791234568');
      await tapConfirm(tester);

      expect(find.text('الرقمان غير متطابقين.'), findsOneWidget);
      expect(orders.orders, isEmpty);
    });

    testWidgets('a missing or one-letter name blocks the order', (tester) async {
      await pump(tester, address: _address);
      await fillCustomer(tester, name: ' ');
      await tapConfirm(tester);
      expect(find.text('الرجاء إدخال اسمك.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'س');
      await tapConfirm(tester);
      expect(find.text('الاسم قصير جداً.'), findsOneWidget);
      expect(orders.orders, isEmpty);
    });

    testWidgets('a non-Jordanian number is rejected before anything is sent', (tester) async {
      await pump(tester, address: _address);
      await fillCustomer(tester, phone: '0651234567');
      await tapConfirm(tester);
      expect(find.textContaining('رقم غير صحيح'), findsOneWidget);
      expect(orders.orders, isEmpty);
    });

    testWidgets('returning guest: details are remembered, shown with a change button, one tap orders', (tester) async {
      SharedPreferences.setMockInitialValues({'customer_name': 'سالم أحمد', 'customer_phone': '+962791234567'});
      await pump(tester, address: _address);

      expect(find.text('سالم أحمد'), findsOneWidget);
      expect(find.text('0791234567'), findsOneWidget);
      expect(find.text('تأكيد رقم الهاتف'), findsNothing);

      await tapConfirm(tester);
      expect(orders.orders.single['phone'], '+962791234567');
    });

    testWidgets('"تغيير" lets a returning guest enter different details', (tester) async {
      SharedPreferences.setMockInitialValues({'customer_name': 'سالم أحمد', 'customer_phone': '+962791234567'});
      await pump(tester, address: _address);

      await tester.tap(find.text('تغيير').last);
      await tester.pumpAndSettle();
      expect(find.text('تأكيد رقم الهاتف'), findsOneWidget);

      await fillCustomer(tester, name: 'خالد', phone: '0771112222');
      await tapConfirm(tester);
      expect(orders.orders.single['name'], 'خالد');
      expect(orders.orders.single['phone'], '+962771112222');
    });

    testWidgets('optional Google link opens login, and backing out keeps the form', (tester) async {
      await pump(tester, address: _address);
      await fillCustomer(tester);

      await tester.tap(find.textContaining('سجّل الدخول بحساب Google'));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN PAGE'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('0791234567'), findsNWidgets(2));
      expect(orders.orders, isEmpty);
    });
  });

  group('server rejections', () {
    const cases = {
      'below_minimum': 'أقل من الحد الأدنى',
      'out_of_stock': 'لم تعد متوفرة',
      'insufficient_stock': 'لم تعد متوفرة',
      'invalid_phone': 'رقم الهاتف غير صحيح',
      'too_many_orders': 'عدة طلبات',
      'invalid_zone': 'لم تعد متاحة',
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key} shows an Arabic explanation and places nothing', (tester) async {
        await pump(tester, address: _address);
        orders.rejectWith = entry.key;
        await fillCustomer(tester);
        await tapConfirm(tester);

        expect(find.textContaining(entry.value), findsOneWidget);
        expect(find.textContaining('TRACKING'), findsNothing);
        expect(orders.orders, isEmpty);
      });
    }
  });

  group('signed in with Google (optional)', () {
    testWidgets('name from Google + phone from the profile: nothing to retype', (tester) async {
      await pump(tester, address: _address, user: _googleUser, profiles: _FakeProfileRepository('+962791234567'));

      expect(find.text('Google Person'), findsOneWidget);
      expect(find.text('0791234567'), findsOneWidget);
      expect(find.textContaining('سجّل الدخول بحساب Google'), findsNothing);

      await tapConfirm(tester);
      expect(orders.orders.single['name'], 'Google Person');
      expect(orders.orders.single['phone'], '+962791234567');
    });

    testWidgets('no phone on the profile yet: name is prefilled, phone asked twice, then saved to the profile', (tester) async {
      final profiles = _FakeProfileRepository();
      await pump(tester, address: _address, user: _googleUser, profiles: profiles);

      expect(find.text('تأكيد رقم الهاتف'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byType(TextFormField).at(0)).controller!.text, 'Google Person');

      await tester.enterText(find.byType(TextFormField).at(1), '0781230000');
      await tester.enterText(find.byType(TextFormField).at(2), '0781230000');
      await tapConfirm(tester);

      expect(orders.orders.single['phone'], '+962781230000');
      expect(profiles.saved, ['+962781230000']);
    });

    testWidgets('a saved address is passed by its server id', (tester) async {
      final persisted = _address.copyWith(isPersisted: true);
      await pump(tester, address: persisted, user: _googleUser, profiles: _FakeProfileRepository('+962791234567'));
      await tapConfirm(tester);
      expect(orders.orders.single['addressId'], 'a1');
    });
  });

  group('delivery or pickup, now or later', () {
    testWidgets('without store settings there is no toggle and no time choice (older server)',
        (tester) async {
      await pump(tester, address: _address);
      expect(find.text('استلام من الفرع'), findsNothing);
      expect(find.text('جدولة موعد'), findsNothing);
      await fillCustomer(tester);
      await tapConfirm(tester);
      expect(orders.orders.single['type'], OrderType.delivery);
      expect(orders.orders.single['scheduled'], isNull);
    });

    testWidgets('delivery is the default; the zone fee and a way to add another address are shown',
        (tester) async {
      await pump(tester, address: _address, settings: _store);
      expect(find.text('توصيل للمنزل'), findsWidgets);
      expect(find.text('إضافة عنوان جديد'), findsOneWidget);
      expect(find.textContaining('رسوم التوصيل إلى الزرقاء الجديدة: 1.500'), findsOneWidget);
      expect(find.text('توصيل الآن'), findsOneWidget);

      await tester.tap(find.text('إضافة عنوان جديد'));
      await tester.pumpAndSettle();
      expect(find.text('ADDRESS FORM'), findsOneWidget);
    });

    testWidgets('pickup: branch details instead of the address, fee 0, total = subtotal',
        (tester) async {
      await pump(tester, address: _address, settings: _store);
      await tester.tap(find.text('استلام من الفرع').first);
      await tester.pumpAndSettle();

      expect(find.text('عنوان التوصيل'), findsNothing);
      expect(find.text('أسواق الطيبات - فرع الزرقاء'), findsOneWidget);
      expect(find.text('الزرقاء، شارع الملك عبدالله'), findsOneWidget);
      expect(find.textContaining('08:00 – 23:00'), findsOneWidget);
      expect(find.text('0791112222'), findsOneWidget);
      expect(find.text('فتح الموقع في الخرائط'), findsOneWidget);
      expect(find.text('0.000 د.أ'), findsOneWidget, reason: 'delivery fee row');
      expect(find.text('10.000 د.أ'), findsNWidgets(2), reason: 'subtotal and total are equal');
    });

    testWidgets('pickup ignores the delivery minimum and needs no address', (tester) async {
      await pump(tester,
          subtotal: 2, settings: _store); // no address at all, below the zone minimum
      await tester.tap(find.text('استلام من الفرع').first);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);

      await fillCustomer(tester);
      await tapConfirm(tester);
      final order = orders.orders.single;
      expect(order['type'], OrderType.pickup);
      expect(order['zoneId'], isNull);
      expect(order['address'], isNull);
      expect(order['addressId'], isNull);
      expect(order['scheduled'], isNull);
    });

    testWidgets('scheduling: pick a slot and it is sent as the slot start', (tester) async {
      await pump(tester, address: _address, settings: _store);
      await tester.tap(find.text('جدولة موعد'));
      await tester.pumpAndSettle();
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('غداً'), findsOneWidget);

      await tester.tap(find.text('12:00 – 13:00'));
      await tester.pumpAndSettle();
      expect(find.text('اليوم 12:00 – 13:00'), findsWidgets);

      await fillCustomer(tester);
      await tapConfirm(tester);
      expect(orders.orders.single['scheduled'], DateTime.utc(2026, 11, 2, 9),
          reason: '12:00 Amman = 09:00 UTC');
    });

    testWidgets('a slot on another day', (tester) async {
      await pump(tester, address: _address, settings: _store);
      await tester.tap(find.text('جدولة موعد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('غداً'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('08:00 – 09:00'));
      await tester.pumpAndSettle();
      await fillCustomer(tester);
      await tapConfirm(tester);
      expect(orders.orders.single['scheduled'], DateTime.utc(2026, 11, 3, 5));
    });

    testWidgets('choosing "schedule" without a slot asks for one', (tester) async {
      await pump(tester, address: _address, settings: _store);
      await tester.tap(find.text('جدولة موعد'));
      await tester.pumpAndSettle();
      await fillCustomer(tester);
      await tapConfirm(tester);
      expect(find.text('الرجاء اختيار موعد التوصيل.'), findsOneWidget);
      expect(orders.orders, isEmpty);
    });

    testWidgets('going back to "now" drops the chosen slot', (tester) async {
      await pump(tester, address: _address, settings: _store);
      await tester.tap(find.text('جدولة موعد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12:00 – 13:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('توصيل الآن'));
      await tester.pumpAndSettle();
      await fillCustomer(tester);
      await tapConfirm(tester);
      expect(orders.orders.single['scheduled'], isNull);
    });

    testWidgets('store closed: "now" is unavailable and a slot must be picked', (tester) async {
      await pump(tester, address: _address, settings: _store, now: _night);
      expect(find.textContaining('المتجر مغلق الآن'), findsOneWidget);
      expect(find.text('08:00 – 09:00'), findsOneWidget, reason: 'slots are shown straight away');

      await fillCustomer(tester);
      await tapConfirm(tester);
      expect(find.text('الرجاء اختيار موعد التوصيل.'), findsOneWidget);
      expect(orders.orders, isEmpty);

      await tester.tap(find.text('08:00 – 09:00'));
      await tester.pumpAndSettle();
      await tapConfirm(tester);
      expect(orders.orders.single['scheduled'], DateTime.utc(2026, 11, 2, 5));
    });

    testWidgets('pickup switched off in the store settings: no toggle', (tester) async {
      const noPickup = StoreSettings(
        branchName: 'x',
        branchAddress: 'x',
        latitude: 0,
        longitude: 0,
        opensAtMinutes: 0,
        closesAtMinutes: 1440,
        pickupEnabled: false,
      );
      await pump(tester, address: _address, settings: noPickup);
      expect(find.text('استلام من الفرع'), findsNothing);
      expect(find.text('توصيل الآن'), findsOneWidget);
    });

    for (final entry in {
      'store_closed': 'المتجر مغلق الآن',
      'invalid_schedule': 'لم يعد متاحاً',
      'pickup_unavailable': 'غير متاح حالياً',
    }.entries) {
      testWidgets('server says ${entry.key}: explained in Arabic', (tester) async {
        await pump(tester, address: _address, settings: _store);
        orders.rejectWith = entry.key;
        await fillCustomer(tester);
        await tapConfirm(tester);
        expect(find.textContaining(entry.value), findsWidgets);
        expect(orders.orders, isEmpty);
      });
    }
  });
}
