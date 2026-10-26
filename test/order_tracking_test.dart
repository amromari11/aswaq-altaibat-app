import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:aswaq_altaibat/core/config/app_config.dart';
import 'package:aswaq_altaibat/core/supabase/supabase_providers.dart';
import 'package:aswaq_altaibat/core/theme/app_colors.dart';
import 'package:aswaq_altaibat/features/orders/data/local/my_orders_store.dart';
import 'package:aswaq_altaibat/features/orders/data/repositories/order_tracking_repository.dart';
import 'package:aswaq_altaibat/features/orders/domain/entities/order_change.dart';
import 'package:aswaq_altaibat/features/orders/domain/entities/order_ref.dart';
import 'package:aswaq_altaibat/features/orders/domain/entities/order_status.dart';
import 'package:aswaq_altaibat/features/orders/domain/entities/order_tracking.dart';
import 'package:aswaq_altaibat/features/orders/presentation/pages/my_orders_page.dart';
import 'package:aswaq_altaibat/features/orders/presentation/pages/order_tracking_page.dart';
import 'package:aswaq_altaibat/features/orders/presentation/providers/order_providers.dart';
import 'package:aswaq_altaibat/features/orders/presentation/widgets/order_map.dart';
import 'package:aswaq_altaibat/features/orders/presentation/widgets/order_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show FlutterMap, Marker, MarkerLayer, PolylineLayer, TileCoordinates, TileLayer, TileProvider;
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

const _ref = OrderRef(id: '3f9a1c00-1111-4111-8111-aaaaaaaaaaaa', token: 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa');
const _ref2 = OrderRef(id: '7b2e4d00-2222-4222-8222-bbbbbbbbbbbb', token: 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb');

OrderTracking _order(
  OrderStatus status, {
  DateTime? createdAt,
  int? eta = 35,
  String? notes,
  double? lat = 32.10,
  double? lng = 36.20,
  DriverLocation? driver,
}) {
  final created = createdAt ?? DateTime.now().subtract(const Duration(minutes: 5));
  return OrderTracking(
    id: _ref.id,
    status: status,
    createdAt: created,
    updatedAt: created.add(const Duration(minutes: 1)),
    subtotal: 8.25,
    deliveryFee: 1.5,
    total: 9.75,
    deliveryAddress: 'الزرقاء الجديدة - شارع الجيش',
    zoneName: 'الزرقاء الجديدة',
    etaMinutes: eta,
    notes: notes,
    deliveryLat: lat,
    deliveryLng: lng,
    driver: driver,
    items: const [
      OrderLine(name: 'حليب', quantity: 2, unitPrice: 2.5, lineTotal: 5.0),
      OrderLine(name: 'جبنة', quantity: 1, unitPrice: 3.25, lineTotal: 3.25),
    ],
  );
}

OrderSummary _summary(OrderRef ref, OrderStatus status, {int minutesAgo = 5}) => OrderSummary(
      ref: ref,
      status: status,
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      total: 9.75,
      itemCount: 3,
      zoneName: 'الزرقاء الجديدة',
    );

/// A scriptable stand-in for Supabase: the test changes what the "server"
/// returns and fires the "broadcast" by hand.
class _FakeRepository implements OrderTrackingRepository {
  OrderTracking? tracking;
  Object? failWith;
  int fetches = 0;
  final changeController = StreamController<OrderChange>.broadcast();
  bool cancelledSubscription = false;
  List<OrderSummary> summaries = [];
  List<OrderRef> accountRefs = [];
  List<OrderRef>? lastListed;

  @override
  Future<OrderTracking?> fetchTracking(OrderRef ref) async {
    fetches++;
    if (failWith != null) throw failWith!;
    return tracking;
  }

  @override
  Stream<OrderChange> changes(OrderRef ref) => Stream<OrderChange>.multi((controller) {
        final sub = changeController.stream.listen(controller.add);
        controller.onCancel = () {
          cancelledSubscription = true;
          return sub.cancel();
        };
      });

  @override
  Future<List<OrderSummary>> listSummaries(List<OrderRef> refs) async {
    lastListed = refs;
    return summaries;
  }

  @override
  Future<List<OrderRef>> fetchAccountOrderRefs() async => accountRefs;
}

const _noAnimation = MediaQueryData(disableAnimations: true);

/// 1x1 transparent PNG: stands in for map tiles so tests make no network calls.
final _blankTile = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class _BlankTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => MemoryImage(_blankTile);
}

DriverLocation _driverAt(double lat, double lng, {Duration ago = Duration.zero}) =>
    DriverLocation(latitude: lat, longitude: lng, updatedAt: DateTime.now().subtract(ago));

/// Containers created by the screen tests, released when each test ends.
final _containers = <ProviderContainer>[];

/// Widget test that cleans up after itself: removes the app, then disposes its
/// Riverpod container, which stops the screens' refresh timers and live
/// subscriptions. (Dropping the whole tree also drops the scope that would
/// otherwise process those disposals, and the test framework fails a test that
/// ends with a timer still pending. In the real app the scope outlives any one
/// screen - see "leaving the screen releases the live subscription".)
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('status model', () {
    test('maps the database statuses onto the 4-step timeline', () {
      expect(OrderStatus.pending.step, 0);
      expect(OrderStatus.confirmed.step, 0, reason: 'received + acknowledged, not yet preparing');
      expect(OrderStatus.preparing.step, 1);
      expect(OrderStatus.outForDelivery.step, 2);
      expect(OrderStatus.delivered.step, 3);
    });

    test('active means not yet delivered or cancelled', () {
      expect([for (final s in OrderStatus.values) if (s.isActive) s.name],
          ['pending', 'confirmed', 'preparing', 'outForDelivery']);
    });

    test('parses database values, tolerating unknowns', () {
      expect(OrderStatus.fromString('out_for_delivery'), OrderStatus.outForDelivery);
      expect(OrderStatus.fromString('cancelled'), OrderStatus.cancelled);
      expect(OrderStatus.fromString('something_new'), OrderStatus.pending);
      expect(OrderStatus.fromString(null), OrderStatus.pending);
    });

    test('every status has Arabic copy', () {
      for (final s in OrderStatus.values) {
        expect(s.labelAr, isNotEmpty);
        expect(s.headlineAr, isNotEmpty);
        expect(s.detailAr, isNotEmpty);
      }
    });
  });

  group('order ref and tracking token', () {
    test('token is a random version-4 uuid', () {
      final token = newTrackingToken();
      expect(token, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect({for (var i = 0; i < 200; i++) newTrackingToken()}, hasLength(200));
    });

    test('token is deterministic for a seeded generator (so the format logic is testable)', () {
      expect(newTrackingToken(Random(7)), newTrackingToken(Random(7)));
    });

    test('short code is the first six characters of the id, upper-cased', () {
      expect(_ref.code, '#3F9A1C');
    });

    test('display code is isolated so a right-to-left layout keeps the # in front', () {
      expect(_ref.displayCode, '\u2066#3F9A1C\u2069');
    });

    test('round-trips through json', () {
      expect(OrderRef.fromJson(_ref.toJson()), _ref);
    });
  });

  test('OrderTracking parses the get_order_tracking payload', () {
    final order = OrderTracking.fromJson({
      'id': _ref.id,
      'status': 'preparing',
      'created_at': '2026-10-27T09:00:00+00:00',
      'updated_at': '2026-10-27T09:10:00+00:00',
      'subtotal': 8.25,
      'delivery_fee': 1.5,
      'total_price': 9.75,
      'payment_method': 'cash',
      'notes': null,
      'delivery_address': 'x',
      'customer_name': 'Amr',
      'zone_name_ar': 'الغويرية',
      'eta_minutes': 25,
      'items': [
        {'name_ar': 'حليب', 'name': 'Milk', 'unit': '1L', 'quantity': 2, 'unit_price': 2.5, 'line_total': 5.0},
      ],
    });
    expect(order.status, OrderStatus.preparing);
    expect(order.total, 9.75);
    expect(order.items.single.name, 'حليب');
    expect(order.expectedBy, order.createdAt.add(const Duration(minutes: 25)));
    expect(OrderTracking.fromJson({...{'id': 'x', 'status': 'pending', 'created_at': '2026-10-27T09:00:00Z', 'updated_at': '2026-10-27T09:00:00Z', 'subtotal': 1, 'delivery_fee': 0, 'total_price': 1}}).expectedBy, isNull);
  });

  group('my orders store', () {
    test('keeps newest first, de-duplicates, and survives a restart', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(myOrderRefsProvider.notifier);
      await notifier.add(_ref);
      await notifier.add(_ref2);
      await notifier.add(_ref); // placed again / reopened: moves to the front, no duplicate
      expect(container.read(myOrderRefsProvider).value, [_ref, _ref2]);

      final afterRestart = ProviderContainer();
      addTearDown(afterRestart.dispose);
      expect(await afterRestart.read(myOrderRefsProvider.future), [_ref, _ref2]);
    });

    test('adding straight away (before the initial load finished) does not lose the order', () async {
      SharedPreferences.setMockInitialValues({'my_orders': '[{"id":"${_ref2.id}","token":"${_ref2.token}"}]'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(myOrderRefsProvider.notifier).add(_ref); // first touch of the provider
      expect(container.read(myOrderRefsProvider).value, [_ref, _ref2]);
    });

    test('keeps at most 50 orders', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      for (var i = 0; i < 60; i++) {
        await container.read(myOrderRefsProvider.notifier).add(OrderRef(id: 'id-$i', token: 't-$i'));
      }
      final refs = container.read(myOrderRefsProvider).value!;
      expect(refs, hasLength(50));
      expect(refs.first.id, 'id-59');
    });

    test('unreadable stored data is treated as empty, not a crash', () async {
      SharedPreferences.setMockInitialValues({'my_orders': 'not json'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(myOrderRefsProvider.future), isEmpty);
    });
  });

  group('live tracking stream', () {
    late _FakeRepository repo;

    ProviderContainer containerFor({Duration poll = const Duration(minutes: 10)}) {
      final container = ProviderContainer(overrides: [
        orderTrackingRepositoryProvider.overrideWithValue(repo),
        trackingPollIntervalProvider.overrideWithValue(poll),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    /// Collects every state the provider emits.
    List<AsyncValue<OrderTracking?>> listen(ProviderContainer container) {
      final seen = <AsyncValue<OrderTracking?>>[];
      container.listen(orderTrackingProvider(_ref), (_, next) => seen.add(next), fireImmediately: true);
      return seen;
    }

    setUp(() => repo = _FakeRepository()..tracking = _order(OrderStatus.pending));

    test('fetches immediately', () async {
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();
      expect(seen.last.value?.status, OrderStatus.pending);
      expect(repo.fetches, 1);
    });

    test('a Realtime broadcast re-fetches and pushes the new status without any refresh', () async {
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();

      repo.tracking = _order(OrderStatus.preparing);
      repo.changeController.add(const OrderRefreshNeeded()); // the database trigger's broadcast arrives
      await pumpEventQueue();

      expect(seen.last.value?.status, OrderStatus.preparing);
      expect(repo.fetches, 2);
    });

    test('the timer is a fallback when no broadcast ever arrives', () async {
      final container = containerFor(poll: const Duration(milliseconds: 40));
      final seen = listen(container);
      await pumpEventQueue();

      repo.tracking = _order(OrderStatus.outForDelivery);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(seen.last.value?.status, OrderStatus.outForDelivery);
    });

    test('a failed refresh keeps the last good value on screen', () async {
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();

      repo.failWith = Exception('offline');
      repo.changeController.add(const OrderRefreshNeeded());
      await pumpEventQueue();

      expect(seen.last.hasError, isFalse);
      expect(seen.last.value?.status, OrderStatus.pending);

      repo.failWith = null;
      repo.tracking = _order(OrderStatus.delivered);
      repo.changeController.add(const OrderRefreshNeeded()); // recovers on the next signal
      await pumpEventQueue();
      expect(seen.last.value?.status, OrderStatus.delivered);
    });

    test('a failed first load is an error (so the page can offer retry)', () async {
      repo.failWith = Exception('offline');
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();
      expect(seen.last.hasError, isTrue);
    });

    test('an unknown id/token pair yields null', () async {
      repo.tracking = null;
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();
      expect(seen.last.hasValue, isTrue);
      expect(seen.last.value, isNull);
    });

    test('leaving the screen unsubscribes and stops polling', () async {
      final container = containerFor(poll: const Duration(milliseconds: 30));
      final subscription = container.listen(orderTrackingProvider(_ref), (_, __) {});
      await pumpEventQueue();
      subscription.close();
      await pumpEventQueue();
      final fetchesAtClose = repo.fetches;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(repo.cancelledSubscription, isTrue, reason: 'the Realtime channel must be released');
      expect(repo.fetches, fetchesAtClose, reason: 'no polling after the screen is gone');
    });
  });

  group('stepper', () {
    Future<void> pumpStepper(WidgetTester tester, OrderStatus status) => tester.pumpWidget(MaterialApp(
          home: MediaQuery(data: _noAnimation, child: Scaffold(body: OrderStepper(status: status))),
        ));

    testWidgets('shows the four stages in order', (tester) async {
      await pumpStepper(tester, OrderStatus.pending);
      final titles = ['تم الاستلام', 'قيد التحضير', 'خرج للتوصيل', 'تم التسليم'];
      final tops = [for (final t in titles) tester.getTopLeft(find.text(t)).dy];
      expect(tops, [...tops]..sort(), reason: 'top to bottom in order');
      for (final t in titles) {
        expect(find.text(t), findsOneWidget);
      }
    });

    for (final c in {
      OrderStatus.pending: (done: 0, active: 'تم الاستلام'),
      OrderStatus.confirmed: (done: 0, active: 'تم الاستلام'),
      OrderStatus.preparing: (done: 1, active: 'قيد التحضير'),
      OrderStatus.outForDelivery: (done: 2, active: 'خرج للتوصيل'),
    }.entries) {
      testWidgets('${c.key.name}: ${c.value.done} step(s) done, "${c.value.active}" highlighted', (tester) async {
        await pumpStepper(tester, c.key);
        expect(find.byIcon(Icons.check), findsNWidgets(c.value.done));
        expect(tester.widget<Text>(find.text(c.value.active)).style!.color, AppColors.accent);
      });
    }

    testWidgets('delivered: every step is complete and none is "active"', (tester) async {
      await pumpStepper(tester, OrderStatus.delivered);
      expect(find.byIcon(Icons.check), findsNWidgets(4));
      for (final t in ['تم الاستلام', 'قيد التحضير', 'خرج للتوصيل', 'تم التسليم']) {
        expect(tester.widget<Text>(find.text(t)).style!.color, isNot(AppColors.accent));
      }
    });
  });


  group('driver and delivery pin (data)', () {
    test('parses the delivery pin and the driver', () {
      final order = OrderTracking.fromJson({
        'id': _ref.id, 'status': 'out_for_delivery', 'created_at': '2026-10-27T09:00:00+00:00',
        'updated_at': '2026-10-27T09:10:00+00:00', 'subtotal': 1, 'delivery_fee': 0, 'total_price': 1,
        'delivery_lat': 32.1, 'delivery_lng': 36.2,
        'driver': {'latitude': 32.05, 'longitude': 36.15, 'updated_at': '2026-10-27T09:12:00+00:00'},
      });
      expect(order.hasDeliveryPin, isTrue);
      expect(order.deliveryLat, 32.1);
      expect(order.driver!.latitude, 32.05);
      expect(order.driver!.updatedAt.toUtc(), DateTime.utc(2026, 10, 27, 9, 12));
    });

    test('no pin and no driver parse as absent, not as zero', () {
      final order = OrderTracking.fromJson({
        'id': _ref.id, 'status': 'pending', 'created_at': '2026-10-27T09:00:00Z',
        'updated_at': '2026-10-27T09:00:00Z', 'subtotal': 1, 'delivery_fee': 0, 'total_price': 1,
        'delivery_lat': null, 'delivery_lng': null, 'driver': null,
      });
      expect(order.hasDeliveryPin, isFalse);
      expect(order.driver, isNull);
    });

    test('withDriver changes only the driver', () {
      final before = _order(OrderStatus.outForDelivery);
      final after = before.withDriver(_driverAt(32.0, 36.0));
      expect(after.driver!.latitude, 32.0);
      expect(after.status, before.status);
      expect(after.total, before.total);
      expect(after.items, before.items);
      expect(after.withDriver(null).driver, isNull);
    });
  });

  group('live driver updates (stream)', () {
    late _FakeRepository repo;

    ProviderContainer containerFor() {
      final container = ProviderContainer(overrides: [
        orderTrackingRepositoryProvider.overrideWithValue(repo),
        trackingPollIntervalProvider.overrideWithValue(const Duration(minutes: 10)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    List<AsyncValue<OrderTracking?>> listen(ProviderContainer container) {
      final seen = <AsyncValue<OrderTracking?>>[];
      container.listen(orderTrackingProvider(_ref), (_, next) => seen.add(next), fireImmediately: true);
      return seen;
    }

    setUp(() => repo = _FakeRepository());

    test('a driver broadcast moves the driver at once, without fetching the order again', () async {
      repo.tracking = _order(OrderStatus.outForDelivery);
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();
      expect(repo.fetches, 1);

      repo.changeController.add(DriverMoved(_driverAt(32.05, 36.15)));
      await pumpEventQueue();

      expect(seen.last.value!.driver!.latitude, 32.05);
      expect(seen.last.value!.status, OrderStatus.outForDelivery);
      expect(repo.fetches, 1, reason: 'the position travels in the broadcast; no extra request');
    });

    test('successive pings keep moving the driver', () async {
      repo.tracking = _order(OrderStatus.outForDelivery);
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();

      for (final lat in [32.01, 32.02, 32.03]) {
        repo.changeController.add(DriverMoved(_driverAt(lat, 36.1)));
        await pumpEventQueue();
        expect(seen.last.value!.driver!.latitude, lat);
      }
    });

    test('a ping for an order that is not out for delivery is ignored', () async {
      repo.tracking = _order(OrderStatus.preparing);
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();

      repo.changeController.add(DriverMoved(_driverAt(32.05, 36.15)));
      await pumpEventQueue();

      expect(seen.last.value!.driver, isNull, reason: 'a driver is never shown outside an active delivery');
    });

    test('a late, older ping cannot undo a newer position', () async {
      repo.tracking = _order(OrderStatus.outForDelivery, driver: _driverAt(32.05, 36.15));
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();

      repo.changeController.add(DriverMoved(_driverAt(32.01, 36.01, ago: const Duration(minutes: 5))));
      await pumpEventQueue();

      expect(seen.last.value!.driver!.latitude, 32.05);
    });

    test('once the order is delivered, a refresh drops the driver', () async {
      repo.tracking = _order(OrderStatus.outForDelivery, driver: _driverAt(32.05, 36.15));
      final container = containerFor();
      final seen = listen(container);
      await pumpEventQueue();
      expect(seen.last.value!.driver, isNotNull);

      repo.tracking = _order(OrderStatus.delivered); // the server no longer returns a driver
      repo.changeController.add(const OrderRefreshNeeded());
      await pumpEventQueue();

      expect(seen.last.value!.status, OrderStatus.delivered);
      expect(seen.last.value!.driver, isNull);
    });

    test('pings that arrive before the first load are not lost or crashing', () async {
      repo.tracking = _order(OrderStatus.outForDelivery);
      final container = containerFor();
      final seen = listen(container);
      repo.changeController.add(DriverMoved(_driverAt(32.05, 36.15))); // before the first fetch completes
      await pumpEventQueue();
      expect(seen.last.hasError, isFalse);
      expect(seen.last.value, isNotNull);
    });
  });

  group('order map', () {
    const store = LatLng(32.07, 36.09);
    const home = LatLng(32.10, 36.20);

    Future<void> pumpMap(WidgetTester tester, {LatLng? home = home, LatLng? driver, bool stale = false}) {
      return tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: _noAnimation,
          child: Scaffold(
            body: SizedBox(
              height: 320,
              child: OrderMap(store: store, home: home, driver: driver, driverStale: stale, tileProvider: _BlankTiles()),
            ),
          ),
        ),
      ));
    }

    List<Marker> markers(WidgetTester tester) =>
        [for (final layer in tester.widgetList<MarkerLayer>(find.byType(MarkerLayer))) ...layer.markers];

    testWidgets('shows the store and the customer\'s pin, with Arabic name tags', (tester) async {
      await pumpMap(tester);
      await tester.pump();
      expect(find.byKey(const ValueKey('map-marker-store')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-marker-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-marker-driver')), findsNothing);
      expect(find.text('المتجر'), findsOneWidget);
      expect(find.text('منزلك'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsOneWidget, reason: 'attribution is required by the OSM tile policy');
    });

    testWidgets('the pins mark exactly the store and home coordinates', (tester) async {
      await pumpMap(tester);
      await tester.pump();
      expect([for (final m in markers(tester)) m.point], containsAll([store, home]));
    });

    testWidgets('without a customer pin only the store is shown, and no route', (tester) async {
      await pumpMap(tester, home: null);
      await tester.pump();
      expect(find.byKey(const ValueKey('map-marker-store')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-marker-home')), findsNothing);
      expect(find.byType(PolylineLayer), findsNothing);
    });

    testWidgets('before the driver sets off: one dotted route, store to home', (tester) async {
      await pumpMap(tester);
      await tester.pump();
      final lines = tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines;
      expect(lines, hasLength(1));
      expect(lines.single.isDotted, isTrue);
      expect(lines.single.points, [store, home]);
    });

    testWidgets('with a driver: solid where they have been, dotted where they are going', (tester) async {
      const driver = LatLng(32.08, 36.14);
      await pumpMap(tester, driver: driver);
      await tester.pump();
      expect(find.byKey(const ValueKey('map-marker-driver')), findsOneWidget);
      expect(find.text('السائق'), findsOneWidget);
      final lines = tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines;
      expect(lines, hasLength(2));
      expect(lines[0].points, [store, driver]);
      expect(lines[0].isDotted, isFalse);
      expect(lines[1].points, [driver, home]);
      expect(lines[1].isDotted, isTrue);
    });

    testWidgets('an assumed driver (still at the store) is drawn beside the store pin, not on top of it', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: _noAnimation,
          child: Scaffold(
            body: SizedBox(height: 320, child: OrderMap(store: store, home: home, driver: store, driverStale: true, driverAssumed: true, tileProvider: _BlankTiles())),
          ),
        ),
      ));
      await tester.pump();
      final storeCentre = tester.getCenter(find.byKey(const ValueKey('map-marker-store')));
      final driverCentre = tester.getCenter(find.byKey(const ValueKey('map-marker-driver')));
      expect((driverCentre.dx - storeCentre.dx).abs(), greaterThan(40), reason: 'clearly apart so neither hides the other');
    });

    testWidgets('the driver marker follows a new position', (tester) async {
      await pumpMap(tester, driver: const LatLng(32.08, 36.14));
      await tester.pump();
      await pumpMap(tester, driver: const LatLng(32.09, 36.18));
      await tester.pumpAndSettle();
      expect(markers(tester).last.point, const LatLng(32.09, 36.18));
    });

    testWidgets('no recenter button until the customer moves the map; then it appears, and works', (tester) async {
      await pumpMap(tester, driver: const LatLng(32.08, 36.14));
      await tester.pump();
      expect(find.byKey(const ValueKey('map-recenter')), findsNothing);

      await tester.drag(find.byType(FlutterMap), const Offset(120, 0));
      await tester.pump();
      expect(find.byKey(const ValueKey('map-recenter')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('map-recenter')));
      await tester.pump();
      expect(find.byKey(const ValueKey('map-recenter')), findsNothing);
    });

    testWidgets('a store-only map (no pin) renders without error', (tester) async {
      await pumpMap(tester, home: null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('markers never overflow their boxes (labelled pins, large text)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true, textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: SizedBox(height: 320, child: OrderMap(store: store, home: home, driver: const LatLng(32.08, 36.14), tileProvider: _BlankTiles())),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('tracking screen', () {
    late _FakeRepository repo;
    late GoRouter router;

    Future<ProviderContainer> pumpPage(WidgetTester tester, {bool canPop = true}) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      router = GoRouter(
        initialLocation: canPop ? '/home' : '/order/${_ref.id}?t=${_ref.token}',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME PAGE'))),
          GoRoute(path: '/orders', builder: (_, __) => const Scaffold(body: Text('ORDERS PAGE'))),
          GoRoute(
            path: '/order/:id',
            builder: (_, state) => OrderTrackingPage(
              orderRef: OrderRef(id: state.pathParameters['id']!, token: state.uri.queryParameters['t'] ?? ''),
            ),
          ),
        ],
      );
      final container = ProviderContainer(overrides: [
        orderTrackingRepositoryProvider.overrideWithValue(repo),
        trackingPollIntervalProvider.overrideWithValue(const Duration(minutes: 10)),
        orderMapTileProviderProvider.overrideWithValue(_BlankTiles()),
      ]);
      _containers.add(container);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        ),
      ));
      await tester.pumpAndSettle();
      if (canPop) {
        router.push('/order/${_ref.id}?t=${_ref.token}');
        await tester.pumpAndSettle();
      }
      return container;
    }

    setUp(() => repo = _FakeRepository());

    screenTest('shows the status, stepper, delivery details, items and totals', (tester) async {
      repo.tracking = _order(OrderStatus.preparing, notes: 'اتصل عند الوصول');
      await pumpPage(tester);

      expect(find.text('تتبع الطلب ${_ref.displayCode}'), findsOneWidget);
      expect(find.text('جارٍ تحضير طلبك'), findsOneWidget);
      expect(find.byType(OrderStepper), findsOneWidget);
      expect(find.text('الزرقاء الجديدة - شارع الجيش'), findsOneWidget);
      expect(find.text('اتصل عند الوصول'), findsOneWidget);
      expect(find.textContaining('حوالي 35 دقيقة'), findsOneWidget);
      expect(find.text('2×'), findsOneWidget);
      expect(find.text('حليب'), findsOneWidget);
      expect(find.text('رسوم التوصيل (الزرقاء الجديدة)'), findsOneWidget);
      expect(find.textContaining('1.500'), findsWidgets);
      expect(find.textContaining('9.750'), findsOneWidget);
      expect(find.text('يتحدّث تلقائياً'), findsOneWidget);
    });

    screenTest('free delivery is shown as such', (tester) async {
      repo.tracking = OrderTracking(
        id: _ref.id, status: OrderStatus.pending, createdAt: DateTime.now(), updatedAt: DateTime.now(),
        subtotal: 25, deliveryFee: 0, total: 25, deliveryAddress: 'x', items: const [],
        zoneName: 'الغويرية',
      );
      await pumpPage(tester);
      expect(find.text('مجاني'), findsOneWidget);
    });

    screenTest('a status broadcast updates the screen instantly, no refresh', (tester) async {
      repo.tracking = _order(OrderStatus.pending);
      await pumpPage(tester);
      expect(find.text('تم استلام طلبك'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      // The admin moves the order along; the database broadcasts.
      repo.tracking = _order(OrderStatus.outForDelivery);
      repo.changeController.add(const OrderRefreshNeeded());
      await tester.pumpAndSettle();

      expect(find.text('تم استلام طلبك'), findsNothing);
      expect(find.text('طلبك في الطريق إليك'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(2), reason: 'received + preparing are now done');

      repo.tracking = _order(OrderStatus.delivered);
      repo.changeController.add(const OrderRefreshNeeded());
      await tester.pumpAndSettle();
      expect(find.text('تم تسليم طلبك'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(4));
      expect(find.text('يتحدّث تلقائياً'), findsNothing, reason: 'nothing left to wait for');
      expect(find.byKey(const ValueKey('order-eta')), findsNothing);
    });

    screenTest('an active order shows the expected arrival time', (tester) async {
      repo.tracking = _order(OrderStatus.preparing, createdAt: DateTime.now().subtract(const Duration(minutes: 5)), eta: 35);
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('order-eta')), findsOneWidget);
      expect(find.textContaining('الوصول المتوقع حوالي'), findsOneWidget);
    });

    screenTest('past the expected time it says so instead of showing a stale time', (tester) async {
      repo.tracking = _order(OrderStatus.preparing, createdAt: DateTime.now().subtract(const Duration(hours: 2)), eta: 35);
      await pumpPage(tester);
      expect(find.textContaining('قد يتأخر قليلاً'), findsOneWidget);
    });

    screenTest('a cancelled order shows a notice, not a timeline', (tester) async {
      repo.tracking = _order(OrderStatus.cancelled);
      await pumpPage(tester);
      expect(find.text('تم إلغاء الطلب'), findsOneWidget);
      expect(find.byType(OrderStepper), findsNothing);
      expect(find.textContaining('ولن يتم توصيله'), findsOneWidget);
    });

    screenTest('"العودة للرئيسية" goes Home and "طلباتي" opens the history', (tester) async {
      repo.tracking = _order(OrderStatus.pending);
      await pumpPage(tester);

      await tester.ensureVisible(find.text('طلباتي'));
      await tester.tap(find.text('طلباتي'));
      await tester.pumpAndSettle();
      expect(find.text('ORDERS PAGE'), findsOneWidget);

      router.push('/order/${_ref.id}?t=${_ref.token}');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('العودة للرئيسية'));
      await tester.tap(find.text('العودة للرئيسية'));
      await tester.pumpAndSettle();
      expect(find.text('HOME PAGE'), findsOneWidget);
    });

    screenTest('opened straight after checkout (nothing to go back to), the app bar offers Home', (tester) async {
      repo.tracking = _order(OrderStatus.pending);
      await pumpPage(tester, canPop: false);
      expect(find.byIcon(Icons.home_outlined), findsWidgets);

      await tester.tap(find.byTooltip('الرئيسية'));
      await tester.pumpAndSettle();
      expect(find.text('HOME PAGE'), findsOneWidget);
    });


    List<Marker> pageMarkers(WidgetTester tester) =>
        [for (final layer in tester.widgetList<MarkerLayer>(find.byType(MarkerLayer))) ...layer.markers];

    screenTest('the map sits at the top of the screen, above the status and timeline', (tester) async {
      repo.tracking = _order(OrderStatus.preparing);
      await pumpPage(tester);
      expect(find.byType(OrderMap), findsOneWidget);
      expect(tester.getTopLeft(find.byType(OrderMap)).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('order-headline'))).dy));
      expect(find.byKey(const ValueKey('map-marker-store')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-marker-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-marker-driver')), findsNothing, reason: 'no driver until the order is out for delivery');
      expect(find.byKey(const ValueKey('map-caption')), findsNothing);
    });

    screenTest('a cancelled order has no map', (tester) async {
      repo.tracking = _order(OrderStatus.cancelled);
      await pumpPage(tester);
      expect(find.byType(OrderMap), findsNothing);
    });

    screenTest('an order with no map pin shows the store only, and says why', (tester) async {
      repo.tracking = _order(OrderStatus.preparing, lat: null, lng: null);
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('map-marker-home')), findsNothing);
      expect(find.byKey(const ValueKey('map-marker-store')), findsOneWidget);
      expect(find.textContaining('لم تحدد موقع التوصيل على الخريطة'), findsOneWidget);
    });

    screenTest('out for delivery with a live driver: the driver is shown and the caption says so', (tester) async {
      repo.tracking = _order(OrderStatus.outForDelivery, driver: _driverAt(32.085, 36.14));
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('map-marker-driver')), findsOneWidget);
      expect(find.textContaining('السائق في الطريق إليك'), findsWidgets);
      expect(pageMarkers(tester).last.point, const LatLng(32.085, 36.14));
    });

    screenTest('out for delivery before any location arrives: greyed driver at the store, and a waiting note', (tester) async {
      repo.tracking = _order(OrderStatus.outForDelivery);
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('map-marker-driver')), findsOneWidget);
      expect(find.textContaining('ننتظر مشاركة موقعه المباشر'), findsOneWidget);
      expect(pageMarkers(tester).last.point, const LatLng(AppConfig.storeLatitude, AppConfig.storeLongitude));
    });

    screenTest('an old driver position is flagged as possibly out of date', (tester) async {
      repo.tracking = _order(OrderStatus.outForDelivery, driver: _driverAt(32.085, 36.14, ago: const Duration(minutes: 10)));
      await pumpPage(tester);
      expect(find.textContaining('قد لا يكون محدّثاً'), findsOneWidget);
    });

    screenTest('a live driver broadcast moves the driver on the map, with no refresh', (tester) async {
      repo.tracking = _order(OrderStatus.outForDelivery, driver: _driverAt(32.080, 36.100));
      await pumpPage(tester);
      expect(pageMarkers(tester).last.point, const LatLng(32.080, 36.100));
      final fetchesBefore = repo.fetches;

      repo.changeController.add(DriverMoved(_driverAt(32.095, 36.180)));
      await tester.pumpAndSettle();

      expect(pageMarkers(tester).last.point, const LatLng(32.095, 36.180));
      expect(repo.fetches, fetchesBefore, reason: 'the broadcast carries the position');
    });

    screenTest('when the order is delivered the driver disappears but the map stays', (tester) async {
      repo.tracking = _order(OrderStatus.outForDelivery, driver: _driverAt(32.085, 36.14));
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('map-marker-driver')), findsOneWidget);

      repo.tracking = _order(OrderStatus.delivered);
      repo.changeController.add(const OrderRefreshNeeded());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('map-marker-driver')), findsNothing);
      expect(find.byType(OrderMap), findsOneWidget);
      expect(find.byKey(const ValueKey('map-marker-home')), findsOneWidget);
    });

    screenTest('an order that goes out for delivery while the screen is open gets its driver', (tester) async {
      repo.tracking = _order(OrderStatus.preparing);
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('map-marker-driver')), findsNothing);

      repo.tracking = _order(OrderStatus.outForDelivery);
      repo.changeController.add(const OrderRefreshNeeded());
      await tester.pumpAndSettle();
      repo.changeController.add(DriverMoved(_driverAt(32.09, 36.15)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('map-marker-driver')), findsOneWidget);
      expect(pageMarkers(tester).last.point, const LatLng(32.09, 36.15));
    });

    screenTest('the page still scrolls to the summary and buttons under the map', (tester) async {
      repo.tracking = _order(OrderStatus.preparing);
      await pumpPage(tester);
      await tester.ensureVisible(find.text('العودة للرئيسية'));
      expect(find.text('ملخص الطلب'), findsOneWidget);
    });

    screenTest('leaving the screen releases the live subscription', (tester) async {
      repo.tracking = _order(OrderStatus.pending);
      await pumpPage(tester); // Home, then tracking pushed on top
      expect(repo.cancelledSubscription, isFalse, reason: 'subscribed while the screen is open');

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('HOME PAGE'), findsOneWidget);
      expect(repo.cancelledSubscription, isTrue, reason: 'channel released once the customer leaves');
    });

    screenTest('an unknown order says so, with a way out', (tester) async {
      repo.tracking = null;
      await pumpPage(tester);
      expect(find.text('لم نجد هذا الطلب'), findsOneWidget);
      expect(find.text('العودة للرئيسية'), findsOneWidget);
    });

    screenTest('a failed load shows retry, and retry loads the order', (tester) async {
      repo.failWith = Exception('offline');
      await pumpPage(tester);
      expect(find.text('تعذر تحميل حالة الطلب'), findsOneWidget);

      repo.failWith = null;
      repo.tracking = _order(OrderStatus.preparing);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('جارٍ تحضير طلبك'), findsOneWidget);
    });
  });

  group('orders history', () {
    late _FakeRepository repo;
    late GoRouter router;

    Future<ProviderContainer> pumpList(WidgetTester tester, {User? user, List<OrderRef> local = const []}) async {
      SharedPreferences.setMockInitialValues({
        if (local.isNotEmpty) 'my_orders': '[${local.map((r) => '{"id":"${r.id}","token":"${r.token}"}').join(',')}]',
      });
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      router = GoRouter(
        initialLocation: '/orders',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME PAGE'))),
          GoRoute(path: '/orders', builder: (_, __) => const MyOrdersPage()),
          GoRoute(
            path: '/order/:id',
            builder: (_, state) => Scaffold(body: Text('TRACKING ${state.pathParameters['id']} ${state.uri.queryParameters['t']}')),
          ),
        ],
      );
      final container = ProviderContainer(overrides: [
        orderTrackingRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(user),
      ]);
      _containers.add(container);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      return container;
    }

    setUp(() => repo = _FakeRepository());

    screenTest('empty: invites the first order', (tester) async {
      await pumpList(tester);
      expect(find.text('لا توجد طلبات بعد'), findsOneWidget);
      await tester.tap(find.text('ابدأ التسوق'));
      await tester.pumpAndSettle();
      expect(find.text('HOME PAGE'), findsOneWidget);
    });

    screenTest('active orders come first, with a track prompt; delivered ones are listed after', (tester) async {
      repo.summaries = [
        _summary(_ref2, OrderStatus.delivered, minutesAgo: 600),
        _summary(_ref, OrderStatus.outForDelivery),
      ];
      await pumpList(tester, local: [_ref, _ref2]);

      expect(find.text('طلبات نشطة'), findsOneWidget);
      expect(find.text('الطلبات السابقة'), findsOneWidget);
      expect(tester.getTopLeft(find.text(_ref.displayCode)).dy, lessThan(tester.getTopLeft(find.text(_ref2.displayCode)).dy));
      expect(find.text('تتبع الطلب'), findsOneWidget, reason: 'only the active order is trackable');
      expect(find.text('خرج للتوصيل'), findsOneWidget);
      expect(find.text('تم التسليم'), findsOneWidget);
    });

    screenTest('tapping an order opens its live tracking with the right id and token', (tester) async {
      repo.summaries = [_summary(_ref, OrderStatus.preparing)];
      await pumpList(tester, local: [_ref]);

      await tester.tap(find.text(_ref.displayCode));
      await tester.pumpAndSettle();
      expect(find.text('TRACKING ${_ref.id} ${_ref.token}'), findsOneWidget);
    });

    screenTest('the device\'s orders are sent to the server as id + token refs', (tester) async {
      repo.summaries = [_summary(_ref, OrderStatus.pending)];
      await pumpList(tester, local: [_ref, _ref2]);
      expect(repo.lastListed, [_ref, _ref2]);
    });

    screenTest('a signed-in customer also sees their account orders, with no duplicates', (tester) async {
      const user = User(id: 'u1', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-10-25T00:00:00Z');
      repo.accountRefs = [_ref2, _ref]; // _ref was also placed on this device
      repo.summaries = [_summary(_ref, OrderStatus.pending), _summary(_ref2, OrderStatus.delivered, minutesAgo: 900)];
      await pumpList(tester, user: user, local: [_ref]);
      expect(repo.lastListed!.map((r) => r.id).toSet(), {_ref.id, _ref2.id});
      expect(repo.lastListed, hasLength(2));
    });

    screenTest('a guest never asks the server for account orders', (tester) async {
      repo.accountRefs = [_ref2];
      repo.summaries = [];
      await pumpList(tester, local: [_ref]);
      expect(repo.lastListed, [_ref]);
    });

    screenTest('a load failure offers retry', (tester) async {
      final failing = _FailingRepository();
      repo = failing;
      await pumpList(tester, local: [_ref]);
      expect(find.text('تعذر تحميل طلباتك'), findsOneWidget);
    });
  });
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<List<OrderSummary>> listSummaries(List<OrderRef> refs) async => throw Exception('offline');
}
