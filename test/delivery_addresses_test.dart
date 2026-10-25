import 'package:aswaq_altaibat/core/supabase/supabase_providers.dart';
import 'package:aswaq_altaibat/features/account/data/repositories/profile_repository.dart';
import 'package:aswaq_altaibat/features/cart/data/repositories/cart_repository.dart';
import 'package:aswaq_altaibat/features/cart/data/repositories/checkout_repository.dart';
import 'package:aswaq_altaibat/features/account/presentation/providers/profile_providers.dart';
import 'package:aswaq_altaibat/features/auth/presentation/pages/login_page.dart';
import 'package:aswaq_altaibat/features/auth/presentation/providers/auth_provider.dart';
import 'package:aswaq_altaibat/features/cart/domain/entities/cart_item.dart';
import 'package:aswaq_altaibat/features/cart/presentation/pages/checkout_page.dart';
import 'package:aswaq_altaibat/features/cart/presentation/providers/checkout_provider.dart';
import 'package:aswaq_altaibat/features/cart/presentation/providers/cart_provider.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/product.dart';
import 'package:aswaq_altaibat/features/location/data/repositories/addresses_repository.dart';
import 'package:aswaq_altaibat/features/location/domain/entities/delivery_zone.dart';
import 'package:aswaq_altaibat/features/location/domain/entities/saved_address.dart';
import 'package:aswaq_altaibat/features/location/presentation/providers/location_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

const _newZarqa = DeliveryZone(
  id: 'c3d625fe-22d7-44e6-bb43-b0ac1318840c',
  nameAr: 'الزرقاء الجديدة',
  deliveryFeeJod: 1.5,
  minOrderJod: 7,
  etaMinutes: 35,
);

SavedAddress _address(String id, {bool isDefault = false}) =>
    SavedAddress(id: id, label: 'L$id', zoneId: _newZarqa.id, details: 'details', isDefault: isDefault);

const _user = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-25T00:00:00Z',
);

/// Records calls and plays the server: assigns ids on insert.
class _FakeAddressesRepository implements AddressesRepository {
  final calls = <String>[];
  var _next = 0;

  @override
  Future<SavedAddress> insert(String userId, SavedAddress address) async {
    calls.add('insert:$userId');
    return address.copyWith(id: 'srv-${_next++}', isPersisted: true);
  }

  @override
  Future<SavedAddress> update(SavedAddress address) async {
    calls.add('update:${address.id}');
    return address;
  }

  @override
  Future<void> setDefault(String id) async => calls.add('setDefault:$id');

  @override
  Future<void> delete(String id) async => calls.add('delete:$id');

  @override
  Future<List<SavedAddress>> fetch(String userId) async => const [];
}

class _FakeCheckoutRepository implements CheckoutRepository {
  final orders = <Map<String, Object?>>[];

  @override
  Future<List<StockIssue>> checkStock(List<CartItem> items) async => const [];

  @override
  Future<String> placeOrder({
    required String userId,
    required List<CartItem> items,
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String paymentMethod = 'cash',
    String? notes,
    double? deliveryFeeOverride,
    String? zoneId,
    String? addressId,
  }) async {
    orders.add({'userId': userId, 'zoneId': zoneId, 'fee': deliveryFeeOverride, 'address': deliveryAddress});
    return 'order-1';
  }
}

class _FakeProfileRepository implements ProfileRepository {
  final saved = <String>[];

  @override
  Future<String?> fetchPhone(String userId) async => null;

  @override
  Future<void> updatePhone(String userId, String phone) async => saved.add(phone);
}

class _FakeCartRepository implements CartRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

ProviderContainer _container({User? user, AddressesRepository? repo}) {
  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWithValue(user),
    if (repo != null) addressesRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('SavedAddressesNotifier (guest)', () {
    test('first address becomes default; flagging another moves the default', () async {
      final n = _container().read(savedAddressesProvider.notifier);
      await n.upsert(_address('a'));
      expect(n.state.single.isDefault, isTrue);

      await n.upsert(_address('b', isDefault: true));
      expect(n.state.where((a) => a.isDefault).map((a) => a.id), ['b']);
    });

    test('removing the default promotes another address', () async {
      final n = _container().read(savedAddressesProvider.notifier);
      await n.upsert(_address('a'));
      await n.upsert(_address('b'));
      n.remove('a');
      expect(n.state.single.id, 'b');
      expect(n.state.single.isDefault, isTrue);
    });

    test('upsert with an existing id replaces instead of duplicating', () async {
      final n = _container().read(savedAddressesProvider.notifier);
      await n.upsert(_address('a'));
      await n.upsert(_address('a').copyWith(label: 'edited'));
      expect(n.state, hasLength(1));
      expect(n.state.single.label, 'edited');
    });
  });

  group('SavedAddressesNotifier (signed in)', () {
    test('new address is inserted server-side and keeps the server id', () async {
      final repo = _FakeAddressesRepository();
      final n = _container(user: _user, repo: repo).read(savedAddressesProvider.notifier);

      await n.upsert(_address('local'));

      expect(repo.calls, ['insert:user-1']);
      expect(n.state.single.id, 'srv-0');
      expect(n.state.single.isPersisted, isTrue);
    });

    test('edit, set-default and delete of persisted rows go to the server', () async {
      final repo = _FakeAddressesRepository();
      final n = _container(user: _user, repo: repo).read(savedAddressesProvider.notifier);
      await n.upsert(_address('x'));
      await n.upsert(_address('y'));
      repo.calls.clear();

      await n.upsert(n.state.first.copyWith(label: 'edited'));
      n.setDefault('srv-1');
      n.remove('srv-1'); // the default → srv-0 is promoted

      expect(repo.calls, ['update:srv-0', 'setDefault:srv-1', 'setDefault:srv-0', 'delete:srv-1']);
      expect(n.state.single.isDefault, isTrue);
    });

    test('a guest never touches the server', () async {
      final repo = _FakeAddressesRepository();
      final n = _container(repo: repo).read(savedAddressesProvider.notifier);
      await n.upsert(_address('a'));
      n.remove('a');
      expect(repo.calls, isEmpty);
    });
  });

  group('CheckoutPage with zones', () {
    const product = Product(id: 'p1', categoryId: 'c', name: 'n', nameAr: 'منتج', price: 2);

    Future<void> pump(
      WidgetTester tester, {
      required double subtotal,
      List<SavedAddress> addresses = const [],
      String? savedPhone,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            profilePhoneProvider.overrideWith((ref) async => savedPhone),
            zonesProvider.overrideWith((ref) async => const [_newZarqa]),
            savedAddressesProvider.overrideWith((ref) {
              final n = SavedAddressesNotifier(ref);
              for (final a in addresses) {
                n.upsert(a);
              }
              return n;
            }),
            cartItemsListProvider.overrideWithValue([const CartItem(product: product, quantity: 1)]),
            cartSubtotalProvider.overrideWithValue(subtotal),
            freeDeliveryRemainingProvider.overrideWithValue(20 - subtotal),
          ],
          child: const MaterialApp(home: CheckoutPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no address: shows add-address prompt', (tester) async {
      await pump(tester, subtotal: 10);
      expect(find.text('إضافة عنوان توصيل'), findsOneWidget);
    });

    testWidgets('below the zone minimum: shows warning and disables confirm', (tester) async {
      await pump(tester, subtotal: 2, addresses: [_address('a')]); // New Zarqa min 7
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

    testWidgets('no saved phone: shows double-entry fields', (tester) async {
      await pump(tester, subtotal: 10, addresses: [_address('a')]);
      expect(find.text('رقم الهاتف'), findsWidgets);
      expect(find.text('تأكيد رقم الهاتف'), findsOneWidget);
    });

    testWidgets('saved phone: shown in local format with a change button', (tester) async {
      await pump(tester, subtotal: 10, addresses: [_address('a')], savedPhone: '+962791234567');
      expect(find.text('0791234567'), findsOneWidget);
      expect(find.text('تأكيد رقم الهاتف'), findsNothing);

      await tester.tap(find.text('تغيير').last);
      await tester.pump();
      expect(find.text('تأكيد رقم الهاتف'), findsOneWidget);
    });

    testWidgets('mismatched phone entries block the order', (tester) async {
      await pump(tester, subtotal: 10, addresses: [_address('a')]);
      await tester.enterText(find.byType(TextFormField).at(0), '0791234567');
      await tester.enterText(find.byType(TextFormField).at(1), '0791234568');
      await tester.tap(find.text('تأكيد الطلب'));
      await tester.pump();
      expect(find.text('الرقمان غير متطابقين.'), findsOneWidget);
    });

    testWidgets('guest confirming a valid order is sent to sign-in, not ordered', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/checkout',
        routes: [
          GoRoute(path: '/checkout', builder: (_, __) => const CheckoutPage()),
          GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LOGIN'))),
        ],
      );
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(null),
        profilePhoneProvider.overrideWith((ref) async => null),
        zonesProvider.overrideWith((ref) async => const [_newZarqa]),
        savedAddressesProvider.overrideWith((ref) {
          final n = SavedAddressesNotifier(ref);
          n.upsert(_address('a'));
          return n;
        }),
        cartItemsListProvider.overrideWithValue([const CartItem(product: product, quantity: 1)]),
        cartSubtotalProvider.overrideWithValue(10),
        freeDeliveryRemainingProvider.overrideWithValue(10),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '0791234567');
      await tester.enterText(find.byType(TextFormField).at(1), '0791234567');
      await tester.tap(find.text('تأكيد الطلب'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN'), findsOneWidget);
      expect(container.read(pendingRedirectProvider), '/checkout');
      expect(container.read(checkoutControllerProvider).isLoading, isFalse);

      // Backing out of login returns to the same, still-filled checkout.
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('0791234567'), findsNWidgets(2));
    });

    testWidgets('after sign-in from checkout, the order is placed without a second tap', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/checkout',
        routes: [
          GoRoute(path: '/checkout', builder: (_, __) => const CheckoutPage()),
          GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LOGIN'))),
          GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
        ],
      );
      final signedInUser = StateProvider<User?>((ref) => null);
      final orders = _FakeCheckoutRepository();
      final profiles = _FakeProfileRepository();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(signedInUser)),
        checkoutRepositoryProvider.overrideWithValue(orders),
        profileRepositoryProvider.overrideWithValue(profiles),
        cartRepositoryProvider.overrideWithValue(_FakeCartRepository()),
        zonesProvider.overrideWith((ref) async => const [_newZarqa]),
        savedAddressesProvider.overrideWith((ref) {
          final n = SavedAddressesNotifier(ref);
          n.upsert(_address('a'));
          return n;
        }),
        cartItemsListProvider.overrideWithValue([const CartItem(product: product, quantity: 1)]),
        cartSubtotalProvider.overrideWithValue(10),
        freeDeliveryRemainingProvider.overrideWithValue(10),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      // Guest: fill in the phone twice and confirm → sent to sign in.
      await tester.enterText(find.byType(TextFormField).at(0), '0791234567');
      await tester.enterText(find.byType(TextFormField).at(1), '0791234567');
      await tester.tap(find.text('تأكيد الطلب'));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(orders.orders, isEmpty);

      // Sign-in completes; main.dart pops the login page back to checkout.
      container.read(signedInUser.notifier).state = _user;
      router.pop();
      await tester.pumpAndSettle();

      expect(profiles.saved, ['+962791234567']);
      expect(orders.orders, hasLength(1));
      expect(orders.orders.single['userId'], 'user-1');
      expect(orders.orders.single['zoneId'], _newZarqa.id);
      expect(find.text('تم تأكيد طلبك'), findsOneWidget);
      expect(container.read(resumeCheckoutAfterSignInProvider), isFalse);
    });

    testWidgets('backing out of login ("متابعة التسوق") cancels the pending auto-order', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
          GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        ],
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      container.read(resumeCheckoutAfterSignInProvider.notifier).state = true;
      router.push('/login');
      await tester.pumpAndSettle();

      await tester.tap(find.text('متابعة التسوق'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(container.read(resumeCheckoutAfterSignInProvider), isFalse);
    });
  });
}
