import 'dart:async';

import 'package:aswaq_altaibat/core/supabase/supabase_providers.dart';
import 'package:aswaq_altaibat/core/utils/external_launcher.dart';
import 'package:aswaq_altaibat/features/account/presentation/pages/account_page.dart';
import 'package:aswaq_altaibat/features/account/presentation/providers/profile_providers.dart';
import 'package:aswaq_altaibat/features/driver/data/repositories/driver_repository.dart';
import 'package:aswaq_altaibat/features/driver/domain/entities/driver_order.dart';
import 'package:aswaq_altaibat/features/driver/domain/entities/driver_profile.dart';
import 'package:aswaq_altaibat/features/driver/presentation/pages/driver_dashboard_page.dart';
import 'package:aswaq_altaibat/features/driver/presentation/providers/driver_providers.dart';
import 'package:aswaq_altaibat/features/driver/presentation/widgets/driver_order_card.dart';
import 'package:aswaq_altaibat/features/orders/domain/entities/order_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

const _user = User(id: 'driver-1', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-11-07T00:00:00Z');
const _id1 = '3f9a1c00-1111-4111-8111-aaaaaaaaaaaa';
const _id2 = '7b2e4d00-2222-4222-8222-bbbbbbbbbbbb';

DriverOrder _order({
  String id = _id1,
  String status = 'confirmed',
  double? lat = 32.07,
  double? lng = 36.09,
  String payment = 'cash',
  int points = 0,
  double total = 11.75,
  String? phone = '+962781234567',
}) =>
    DriverOrder.fromJson({
      'id': id,
      'status': status,
      'order_type': 'delivery',
      'created_at': '2026-11-07T10:15:00Z',
      'scheduled_time': null,
      'picked_up_at': null,
      'customer_name': 'أحمد علي',
      'customer_phone': phone,
      'delivery_address': 'شارع الجيش، عمارة 5',
      'delivery_lat': lat,
      'delivery_lng': lng,
      'zone_name_ar': 'الزرقاء الجديدة',
      'notes': 'الطابق الثاني',
      'subtotal': 10.75,
      'delivery_fee': 1.5,
      'discount_amount': 0.5,
      'total_price': total,
      'payment_method': payment,
      'loyalty_points_redeemed': points,
      'item_count': 4,
    });

class _FakeDriverRepository implements DriverRepository {
  DriverProfile profile = const DriverProfile(role: 'driver', fullName: 'خالد');
  List<DriverOrder> orders = [];
  final calls = <String>[];
  Object? failWith;
  int fetches = 0;
  final pings = StreamController<void>.broadcast();

  @override
  Future<DriverProfile> fetchProfile(String userId) async => profile;

  @override
  Future<bool> setAvailable(bool available) async {
    calls.add('available:$available');
    if (failWith != null) throw failWith!;
    return available;
  }

  @override
  Future<List<DriverOrder>> fetchAssignedOrders() async {
    fetches++;
    return orders;
  }

  @override
  Future<void> pickUp(String orderId) async {
    calls.add('pickUp:$orderId');
    if (failWith != null) throw failWith!;
    orders = [for (final o in orders) o.id == orderId ? _order(id: o.id, status: 'out_for_delivery') : o];
  }

  @override
  Future<DeliveryResult> markDelivered(String orderId) async {
    calls.add('delivered:$orderId');
    orders = orders.where((o) => o.id != orderId).toList();
    return const DeliveryResult(pointsAwarded: 10, available: true);
  }

  @override
  Stream<void> changes(String driverId) => pings.stream;
}

final _containers = <ProviderContainer>[];

/// Removes the app and disposes its container (stops the list's refresh timer).
void screenTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    for (final container in _containers) {
      container.dispose();
    }
    _containers.clear();
  });
}

void main() {
  group('DriverOrder', () {
    test('reads the database row', () {
      final o = _order();
      expect(o.code, '#3F9A1C');
      expect(o.status, OrderStatus.confirmed);
      expect(o.isPickedUp, isFalse);
      expect(o.total, 11.75);
      expect(o.itemCount, 4);
      expect(o.zoneName, 'الزرقاء الجديدة');
    });

    test('payment reads as cash, card or points', () {
      expect(_order().paymentLabelAr, 'نقداً عند الاستلام');
      expect(_order(payment: 'card').paymentLabelAr, 'بطاقة');
      expect(_order(points: 20).paymentLabelAr, 'نقداً عند الاستلام + نقاط (20 نقطة)');
      expect(_order(points: 300, total: 0).paymentLabelAr, 'نقاط (300 نقطة)');
      expect(_order(points: 300, total: 0).paymentMethodAr, 'نقاط');
    });

    test('Google Maps opens the pin, or searches the address without one', () {
      final pinned = _order().mapsUri;
      expect(pinned.host, 'www.google.com');
      expect(pinned.path, '/maps/search/');
      expect(pinned.queryParameters, {'api': '1', 'query': '32.07,36.09'});
      expect(_order(lat: null, lng: null).mapsUri.queryParameters['query'], 'شارع الجيش، عمارة 5، الزرقاء');
    });

    test('the dialler gets the customer number; no number, no call', () {
      expect(_order().callUri.toString(), 'tel:+962781234567');
      expect(_order(phone: null).callUri, isNull);
    });

    test('delivery result', () {
      final r = DeliveryResult.fromJson({'points_awarded': 12, 'available': true, 'already_delivered': false});
      expect(r.pointsAwarded, 12);
      expect(r.available, isTrue);
    });

    test('database error codes become Arabic messages', () {
      expect(DriverRepository.messageFor('not_a_driver'), 'هذا الحساب غير مسجّل كسائق.');
      expect(DriverRepository.messageFor('order_not_found'), 'هذا الطلب لم يعد مسنداً إليك.');
      expect(DriverRepository.messageFor('invalid_status'), contains('حالة الطلب'));
      expect(DriverRepository.messageFor('something else'), 'تعذّر تنفيذ الطلب، حاول مرة أخرى.');
    });
  });

  group('driver dashboard', () {
    late _FakeDriverRepository repo;
    final launched = <Uri>[];

    setUp(() {
      repo = _FakeDriverRepository();
      launched.clear();
    });

    Future<ProviderContainer> pumpDashboard(WidgetTester tester, {User? user = _user}) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [
        driverRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(user),
        externalLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
      ]);
      _containers.add(container);
      final router = GoRouter(initialLocation: '/driver', routes: [
        GoRoute(path: '/driver', builder: (_, __) => const DriverDashboardPage()),
        GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
        GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return container;
    }

    Switch availabilitySwitch(WidgetTester tester) => tester.widget<Switch>(find.byKey(DriverDashboardPage.availabilityKey));

    screenTest('a customer account is told it is not a driver', (tester) async {
      repo.profile = DriverProfile.customer;
      await pumpDashboard(tester);
      expect(find.textContaining('غير مسجّل كسائق'), findsOneWidget);
      expect(find.byKey(DriverDashboardPage.availabilityKey), findsNothing);
      expect(repo.fetches, 0);
    });

    screenTest('signed out, it asks for the driver to sign in', (tester) async {
      await pumpDashboard(tester, user: null);
      expect(find.textContaining('سجّل الدخول بحساب السائق'), findsOneWidget);
    });

    screenTest('the availability switch saves to the server', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('متاح للتوصيل'), findsOneWidget);
      expect(availabilitySwitch(tester).value, isFalse);

      await tester.tap(find.byKey(DriverDashboardPage.availabilityKey));
      await tester.pumpAndSettle();

      expect(repo.calls, ['available:true']);
      expect(availabilitySwitch(tester).value, isTrue);
      expect(find.text('يراك المتجر متاحاً لاستلام طلبات جديدة'), findsOneWidget);
    });

    screenTest('a refused toggle rolls back and says why', (tester) async {
      repo.failWith = const DriverActionException('هذا الحساب غير مسجّل كسائق.');
      await pumpDashboard(tester);
      await tester.tap(find.byKey(DriverDashboardPage.availabilityKey));
      await tester.pumpAndSettle();

      expect(availabilitySwitch(tester).value, isFalse);
      expect(find.text('هذا الحساب غير مسجّل كسائق.'), findsOneWidget);
    });

    screenTest('an order shows the customer, phone, address, total and payment', (tester) async {
      repo.orders = [_order(points: 20)];
      await pumpDashboard(tester);

      expect(find.text('#3F9A1C'), findsOneWidget);
      expect(find.text('أحمد علي'), findsOneWidget);
      expect(find.text('0781234567'), findsOneWidget);
      expect(find.text('شارع الجيش، عمارة 5 — الزرقاء الجديدة'), findsOneWidget);
      expect(find.text('الطابق الثاني'), findsOneWidget);
      expect(find.text('11.750 د.أ'), findsOneWidget);
      expect(find.text('نقداً عند الاستلام'), findsOneWidget);
      expect(find.text('+ 20 نقطة من رصيده'), findsOneWidget);
      expect(find.byKey(DriverOrderCard.pickUpKey(_id1)), findsOneWidget);
    });

    screenTest('the map and call buttons open Google Maps and the dialler', (tester) async {
      repo.orders = [_order()];
      await pumpDashboard(tester);

      await tester.tap(find.byKey(DriverOrderCard.mapsKey(_id1)));
      await tester.tap(find.byKey(DriverOrderCard.callKey(_id1)));
      await tester.pumpAndSettle();

      expect(launched, hasLength(2));
      expect(launched[0].queryParameters['query'], '32.07,36.09');
      expect(launched[1].toString(), 'tel:+962781234567');
    });

    screenTest('picking up sends the order out for delivery', (tester) async {
      repo.orders = [_order()];
      await pumpDashboard(tester);

      await tester.tap(find.byKey(DriverOrderCard.pickUpKey(_id1)));
      await tester.pumpAndSettle();

      expect(repo.calls, ['pickUp:$_id1']);
      expect(find.byKey(DriverOrderCard.deliveredKey(_id1)), findsOneWidget);
      expect(find.text('خرج للتوصيل'), findsOneWidget);
    });

    screenTest('a refused pick-up keeps the order and explains', (tester) async {
      repo.orders = [_order()];
      repo.failWith = const DriverActionException('هذا الطلب لم يعد مسنداً إليك.');
      await pumpDashboard(tester);

      await tester.tap(find.byKey(DriverOrderCard.pickUpKey(_id1)));
      await tester.pumpAndSettle();

      expect(find.text('هذا الطلب لم يعد مسنداً إليك.'), findsOneWidget);
      expect(find.byKey(DriverOrderCard.pickUpKey(_id1)), findsOneWidget);
    });

    screenTest('delivering asks to confirm the cash, then reports the points', (tester) async {
      repo.orders = [_order(status: 'out_for_delivery')];
      await pumpDashboard(tester);

      await tester.tap(find.byKey(DriverOrderCard.deliveredKey(_id1)));
      await tester.pumpAndSettle();
      expect(find.textContaining('11.750 د.أ نقداً'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('تم التسليم')));
      await tester.pumpAndSettle();

      expect(repo.calls, ['delivered:$_id1']);
      expect(find.text('تم التسليم ✓ — أُضيفت 10 نقطة لحساب الزبون'), findsOneWidget);
      expect(find.textContaining('لا توجد طلبات مسندة إليك'), findsOneWidget);
      expect(availabilitySwitch(tester).value, isTrue, reason: 'the server switched availability back on');
    });

    screenTest('cancelling the confirmation changes nothing', (tester) async {
      repo.orders = [_order(status: 'out_for_delivery')];
      await pumpDashboard(tester);

      await tester.tap(find.byKey(DriverOrderCard.deliveredKey(_id1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(repo.calls, isEmpty);
      expect(find.byKey(DriverOrderCard.deliveredKey(_id1)), findsOneWidget);
    });

    screenTest('a new assignment from the shop appears by itself', (tester) async {
      repo.orders = [_order()];
      await pumpDashboard(tester);
      expect(find.byType(DriverOrderCard), findsOneWidget);

      repo.orders = [_order(), _order(id: _id2)];
      repo.pings.add(null);
      await tester.pumpAndSettle();

      expect(find.byType(DriverOrderCard), findsNWidgets(2));
      expect(find.text('#7B2E4D'), findsOneWidget);
    });

    screenTest('no orders: says so', (tester) async {
      await pumpDashboard(tester);
      expect(find.textContaining('لا توجد طلبات مسندة إليك حالياً'), findsOneWidget);
    });
  });

  group('account tab', () {
    Future<void> pumpAccount(WidgetTester tester, {required bool driver}) async {
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_user),
        profilePhoneProvider.overrideWith((ref) async => null),
        isDriverProvider.overrideWithValue(driver),
      ]);
      _containers.add(container);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: AccountPage())),
      ));
      await tester.pumpAndSettle();
    }

    screenTest('a driver gets a way back into driver mode', (tester) async {
      await pumpAccount(tester, driver: true);
      expect(find.text('وضع السائق'), findsOneWidget);
    });

    screenTest('a customer does not', (tester) async {
      await pumpAccount(tester, driver: false);
      expect(find.text('وضع السائق'), findsNothing);
    });
  });
}
