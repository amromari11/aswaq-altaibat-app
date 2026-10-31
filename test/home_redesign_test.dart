import 'package:aswaq_altaibat/core/supabase/supabase_providers.dart';
import 'package:aswaq_altaibat/core/widgets/brand_logo.dart';
import 'package:aswaq_altaibat/features/banners/domain/entities/promo_banner.dart';
import 'package:aswaq_altaibat/features/banners/presentation/providers/banner_providers.dart';
import 'package:aswaq_altaibat/features/banners/presentation/widgets/promo_banner_carousel.dart';
import 'package:aswaq_altaibat/features/cart/data/repositories/cart_repository.dart';
import 'package:aswaq_altaibat/features/cart/domain/entities/fulfillment.dart';
import 'package:aswaq_altaibat/features/cart/presentation/providers/cart_provider.dart';
import 'package:aswaq_altaibat/features/cart/presentation/providers/fulfillment_providers.dart';
import 'package:aswaq_altaibat/features/categories/presentation/providers/selected_category_provider.dart';
import 'package:aswaq_altaibat/features/home/data/repositories/home_repository.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/category.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/product.dart';
import 'package:aswaq_altaibat/features/home/presentation/pages/home_page.dart';
import 'package:aswaq_altaibat/features/home/presentation/providers/home_providers.dart';
import 'package:aswaq_altaibat/features/home/presentation/widgets/floating_cart_bar.dart';
import 'package:aswaq_altaibat/features/home/presentation/widgets/home_search_bar.dart';
import 'package:aswaq_altaibat/features/home/presentation/widgets/product_card.dart';
import 'package:aswaq_altaibat/features/location/domain/entities/delivery_zone.dart';
import 'package:aswaq_altaibat/features/location/domain/entities/saved_address.dart';
import 'package:aswaq_altaibat/features/location/presentation/providers/delivery_eta_provider.dart';
import 'package:aswaq_altaibat/features/location/presentation/providers/location_providers.dart';
import 'package:aswaq_altaibat/features/recommendations/presentation/providers/recommendations_providers.dart';
import 'package:aswaq_altaibat/features/search/data/voice_search_service.dart';
import 'package:aswaq_altaibat/features/search/presentation/pages/barcode_scan_page.dart';
import 'package:aswaq_altaibat/features/search/presentation/providers/search_input_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _zone = DeliveryZone(
  id: 'c3d625fe-22d7-44e6-bb43-b0ac1318840c',
  nameAr: 'الزرقاء الجديدة',
  deliveryFeeJod: 1.5,
  minOrderJod: 7,
  etaMinutes: 35,
);
const _fastZone = DeliveryZone(id: 'z2', nameAr: 'الغويرية', deliveryFeeJod: 1, minOrderJod: 5, etaMinutes: 20);

final _address = SavedAddress(id: 'a1', label: 'المنزل', zoneId: _zone.id, details: 'شارع الجيش', isDefault: true);

Product _product(String id, {String name = 'منتج', double price = 2, double? discount, String? unit}) => Product(
      id: id,
      categoryId: 'c1',
      name: name,
      nameAr: '$name $id',
      price: price,
      discountPrice: discount,
      unit: unit,
    );

const _open = StoreSettings(
  branchName: 'الفرع',
  branchAddress: 'الزرقاء',
  latitude: 32,
  longitude: 36,
  opensAtMinutes: 8 * 60,
  closesAtMinutes: 23 * 60,
);

/// 10:30 in Amman (UTC+3), open.
final _morning = DateTime.utc(2026, 11, 2, 7, 30);

/// 02:00 in Amman, closed.
final _night = DateTime.utc(2026, 11, 1, 23, 0);

class _FakeCartRepository implements CartRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeVoice implements VoiceSearchService {
  bool available = true;
  bool listening = false;
  void Function(String, bool)? onWords;
  void Function()? onStopped;
  int stops = 0;

  @override
  bool get isListening => listening;

  @override
  Future<bool> start({required void Function(String, bool) onWords, required void Function() onStopped}) async {
    if (!available) return false;
    this.onWords = onWords;
    this.onStopped = onStopped;
    listening = true;
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    listening = false;
  }
}

/// Plays Supabase for the Home page: everything is canned, nothing leaves the test.
class _Setup {
  List<Product> bestSellers = [];
  List<Product> weeklyOffers = [];
  List<Product> latest = [];
  List<Product> searchResults = [];
  List<PromoBanner> banners = [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    _Setup? setup,
    _FakeVoice? voice,
    DateTime? now,
    List<DeliveryZone> zones = const [_zone],
    bool withAddress = true,
    StoreSettings? store = _open,
    GoRouter? router,
  }) async {
    final s = setup ?? _Setup();
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final goRouter = router ??
        GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const Scaffold(body: HomePage())),
            GoRoute(path: '/account', builder: (_, __) => const Scaffold(body: Text('ACCOUNT PAGE'))),
            GoRoute(path: '/addresses', builder: (_, __) => const Scaffold(body: Text('ADDRESSES PAGE'))),
            GoRoute(
              path: '/scan',
              builder: (_, __) => BarcodeScanPage(cameraBuilder: (onCode) => TextButton(onPressed: () => onCode('6281001234567'), child: const Text('FAKE CAMERA'))),
            ),
          ],
        );
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(null),
      cartRepositoryProvider.overrideWithValue(_FakeCartRepository()),
      zonesProvider.overrideWith((ref) async => zones),
      savedAddressesProvider.overrideWith((ref) => _Preset(ref, [if (withAddress) _address])),
      storeSettingsProvider.overrideWith((ref) async => store),
      clockProvider.overrideWithValue(() => now ?? _morning),
      promoBannersProvider.overrideWith((ref) async => s.banners),
      categoriesProvider.overrideWith((ref) async => const [Category(id: 'c1', name: 'Dairy', nameAr: 'ألبان')]),
      orderAgainProvider.overrideWith((ref) async => const []),
      bestSellersProvider.overrideWith((ref) async => s.bestSellers),
      weeklyOffersProvider.overrideWith((ref) async => s.weeklyOffers),
      latestProductsProvider.overrideWith((ref) async => s.latest),
      homeRecommendationsProvider.overrideWith((ref) async => const []),
      searchResultsProvider.overrideWith((ref) async => s.searchResults),
      voiceSearchServiceProvider.overrideWithValue(voice ?? _FakeVoice()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: goRouter)));
    // Pictures and the logo load asynchronously; never settle on the looping shimmer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  group('delivery header', () {
    testWidgets('shows the logo, how fast we deliver (from the zone) and where to', (tester) async {
      await pumpHome(tester);
      expect(find.byType(BrandLogo), findsOneWidget);
      expect(find.text('التوصيل خلال'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('delivery-eta'))).data, '30–35 دقيقة');
      expect(find.byIcon(Icons.bolt), findsOneWidget);
      expect(find.text('المنزل · الزرقاء الجديدة'), findsOneWidget);
      expect(find.byKey(const ValueKey('store-closed-chip')), findsNothing);
    });

    testWidgets('no saved address: quotes the fastest zone and asks for a location', (tester) async {
      await pumpHome(tester, zones: const [_zone, _fastZone], withAddress: false);
      expect(tester.widget<Text>(find.byKey(const ValueKey('delivery-eta'))).data, '15–20 دقيقة');
      expect(find.text('حدد موقع التوصيل'), findsOneWidget);
    });

    testWidgets('closed at night: the estimate stays, with a closed notice and the opening time', (tester) async {
      await pumpHome(tester, now: _night);
      expect(tester.widget<Text>(find.byKey(const ValueKey('delivery-eta'))).data, '30–35 دقيقة');
      expect(find.textContaining('المتجر مغلق الآن — نفتح 08:00'), findsOneWidget);
    });

    testWidgets('tapping the location opens the address list, the avatar opens the account', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('المنزل · الزرقاء الجديدة'));
      await tester.pumpAndSettle();
      expect(find.text('ADDRESSES PAGE'), findsOneWidget);
    });

    testWidgets('the account button goes to the account page', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT PAGE'), findsOneWidget);
    });

    test('delivery time ranges', () {
      expect(etaRangeFor(35), (low: 30, high: 35));
      expect(etaRangeFor(10), (low: 10, high: 10));
      expect(etaRangeFor(2), (low: 5, high: 5));
      expect(etaRangeLabel(etaRangeFor(35)), '30–35 دقيقة');
      expect(etaRangeLabel(etaRangeFor(35), short: true), '30–35 د');
      expect(etaRangeLabel(etaRangeFor(8)), '8 دقيقة');
    });
  });

  group('search: voice and barcode', () {
    testWidgets('shows both buttons; each is hidden when its handler is null', (tester) async {
      Future<void> pumpBar({VoidCallback? voice, VoidCallback? scan}) => tester.pumpWidget(MaterialApp(
            home: Scaffold(body: HomeSearchBar(onChanged: (_) {}, onSubmitted: (_) {}, onVoice: voice, onScan: scan)),
          ));
      await pumpBar(voice: () {}, scan: () {});
      expect(find.byKey(HomeSearchBar.voiceKey), findsOneWidget);
      expect(find.byKey(HomeSearchBar.scanKey), findsOneWidget);
      await pumpBar(scan: () {});
      expect(find.byKey(HomeSearchBar.voiceKey), findsNothing);
      await pumpBar();
      expect(find.byKey(HomeSearchBar.scanKey), findsNothing);
    });

    testWidgets('voice: words heard fill the search box and drive the results', (tester) async {
      final voice = _FakeVoice();
      final container = await pumpHome(tester, voice: voice);
      await tester.tap(find.byKey(HomeSearchBar.voiceKey));
      await tester.pump();
      expect(voice.listening, isTrue);
      expect(find.byIcon(Icons.mic), findsOneWidget, reason: 'the button shows it is listening');

      voice.onWords!('حليب', false);
      await tester.pump();
      expect(container.read(searchQueryProvider), 'حليب');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'حليب');

      voice.onStopped!();
      await tester.pump();
      expect(find.byIcon(Icons.mic_none), findsOneWidget, reason: 'back to idle when listening ends');
    });

    testWidgets('voice: a second tap stops listening', (tester) async {
      final voice = _FakeVoice();
      await pumpHome(tester, voice: voice);
      await tester.tap(find.byKey(HomeSearchBar.voiceKey));
      await tester.pump();
      await tester.tap(find.byKey(HomeSearchBar.voiceKey));
      await tester.pump();
      expect(voice.stops, 1);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets('voice: unavailable (no permission / browser) says so instead of failing silently', (tester) async {
      final voice = _FakeVoice()..available = false;
      await pumpHome(tester, voice: voice);
      await tester.tap(find.byKey(HomeSearchBar.voiceKey));
      await tester.pump();
      expect(find.textContaining('البحث الصوتي غير متاح'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets('voice: leaving the page while listening stops the microphone', (tester) async {
      final voice = _FakeVoice();
      await pumpHome(tester, voice: voice);
      await tester.tap(find.byKey(HomeSearchBar.voiceKey));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(voice.stops, 1);
    });

    testWidgets('scan: the scanned barcode becomes the search', (tester) async {
      final container = await pumpHome(tester);
      await tester.tap(find.byKey(HomeSearchBar.scanKey));
      await tester.pumpAndSettle();
      expect(find.text('FAKE CAMERA'), findsOneWidget);
      await tester.tap(find.text('FAKE CAMERA'));
      await tester.pumpAndSettle();
      expect(container.read(searchQueryProvider), '6281001234567');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '6281001234567');
    });

    testWidgets('scan: a typed barcode works the same (no camera needed)', (tester) async {
      final container = await pumpHome(tester);
      await tester.tap(find.byKey(HomeSearchBar.scanKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(BarcodeScanPage.manualFieldKey), ' 6281009876543 ');
      await tester.tap(find.byKey(BarcodeScanPage.manualSubmitKey));
      await tester.pumpAndSettle();
      expect(container.read(searchQueryProvider), '6281009876543');
    });

    testWidgets('scan: backing out or an empty entry changes nothing', (tester) async {
      final container = await pumpHome(tester);
      await tester.tap(find.byKey(HomeSearchBar.scanKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BarcodeScanPage.manualSubmitKey));
      await tester.pumpAndSettle();
      expect(find.text('FAKE CAMERA'), findsOneWidget, reason: 'an empty entry does not close the scanner');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(container.read(searchQueryProvider), '');
    });

    test('a barcode searches the SKU as well as the names; typed punctuation cannot break the filter', () {
      expect(HomeRepository.searchFilter('حليب'), 'name.ilike.%حليب%,name_ar.ilike.%حليب%');
      expect(HomeRepository.searchFilter('6281001234567'), 'name.ilike.%6281001234567%,name_ar.ilike.%6281001234567%,sku.eq.6281001234567');
      expect(HomeRepository.searchFilter('12345'), isNot(contains('sku.eq')), reason: 'short numbers are not barcodes');
      final nasty = HomeRepository.searchFilter('a,b),sku.eq.1(%*x');
      expect(nasty, 'name.ilike.%a b sku.eq.1 x%,name_ar.ilike.%a b sku.eq.1 x%');
      expect(','.allMatches(nasty).length, 1, reason: 'only the separator between the two filters is left');
    });
  });

  group('best sellers', () {
    final many = [for (var i = 1; i <= 9; i++) _product('b$i', name: 'مبيع')];

    testWidgets('a "best sellers" shelf with the first six, and show all / show less', (tester) async {
      await pumpHome(tester, setup: _Setup()..bestSellers = many);
      expect(find.text('الأكثر مبيعاً'), findsOneWidget);
      expect(find.byType(ProductCard), findsNWidgets(6));
      expect(find.text('عرض الكل'), findsOneWidget);

      await tester.tap(find.text('عرض الكل'));
      await tester.pump();
      expect(find.byType(ProductCard), findsNWidgets(9));
      expect(find.text('عرض أقل'), findsOneWidget);

      await tester.tap(find.text('عرض أقل'));
      await tester.pump();
      expect(find.byType(ProductCard), findsNWidgets(6));
    });

    testWidgets('a short list has no "show all"', (tester) async {
      await pumpHome(tester, setup: _Setup()..bestSellers = many.take(3).toList());
      expect(find.byType(ProductCard), findsNWidgets(3));
      expect(find.text('عرض الكل'), findsNothing);
    });

    testWidgets('nothing to show (or an older server): the shelf is simply not there', (tester) async {
      await pumpHome(tester, setup: _Setup()..latest = [_product('l1')]);
      expect(find.text('الأكثر مبيعاً'), findsNothing);
      expect(find.text('تصفح منتجاتنا'), findsOneWidget);
    });

    testWidgets('the browse shelf below does not repeat the best sellers', (tester) async {
      await pumpHome(tester, setup: _Setup()..bestSellers = [_product('b1')]..latest = [_product('b1'), _product('l2')]);
      expect(find.text('منتج b1'), findsOneWidget, reason: 'listed once, in the best sellers');
      expect(find.text('منتج l2'), findsOneWidget);
    });

    testWidgets('weekly offers still get their own shelf', (tester) async {
      await pumpHome(tester, setup: _Setup()..bestSellers = [_product('b1')]..weeklyOffers = [_product('w1', discount: 1.5)]);
      expect(find.text('عروض هذا الأسبوع'), findsOneWidget);
      expect(find.text('الأكثر مبيعاً'), findsOneWidget);
    });

    testWidgets('searching hides the shelf and shows the results', (tester) async {
      final container = await pumpHome(tester, setup: _Setup()..bestSellers = many..searchResults = [_product('r1')]);
      container.read(searchQueryProvider.notifier).state = 'حليب';
      await tester.pump();
      await tester.pump();
      expect(find.text('الأكثر مبيعاً'), findsNothing);
      expect(find.text('نتائج البحث'), findsOneWidget);
      expect(find.text('منتج r1'), findsOneWidget);
    });

    testWidgets('picking a category hides the shelf', (tester) async {
      final container = await pumpHome(tester, setup: _Setup()..bestSellers = many);
      container.read(selectedCategoryProvider.notifier).state = 'c1';
      await tester.pump();
      expect(find.text('الأكثر مبيعاً'), findsNothing);
    });
  });

  group('hero banner', () {
    testWidgets('a tappable banner shows its title and a shop-now button; a plain one does not', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PromoBannerCarousel(
            banners: const [
              PromoBanner(id: '1', imageUrl: 'https://img.test/1.webp', title: 'خصومات', targetType: BannerTargetType.category, targetId: 'c1'),
            ],
            onBannerTap: (_) {},
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('خصومات'), findsOneWidget);
      expect(find.text('تسوّق الآن'), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PromoBannerCarousel(banners: [PromoBanner(id: '2', imageUrl: 'https://img.test/2.webp', title: 'عرض')]),
        ),
      ));
      await tester.pump();
      expect(find.text('عرض'), findsOneWidget);
      expect(find.text('تسوّق الآن'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('product card', () {
    late ProviderContainer container;

    Future<void> pumpCard(WidgetTester tester, Product product, {List<DeliveryZone> zones = const [_zone]}) async {
      container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(null),
        cartRepositoryProvider.overrideWithValue(_FakeCartRepository()),
        zonesProvider.overrideWith((ref) async => zones),
        categoriesProvider.overrideWith((ref) async => const []),
        savedAddressesProvider.overrideWith((ref) => _Preset(ref, [_address])),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: Center(child: SizedBox(width: 180, height: 290, child: ProductCard(product: product)))),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('discounted: red tag with the percentage, new price, struck-through old price, delivery time and pack size', (tester) async {
      await pumpCard(tester, _product('p', price: 5, discount: 3.65, unit: 'لتر'));
      expect(find.text('خصم 27%'), findsOneWidget);
      expect(find.text('3.650 د.أ'), findsOneWidget);
      final old = tester.widget<Text>(find.text('5.000 د.أ'));
      expect(old.style!.decoration, TextDecoration.lineThrough);
      expect(tester.widget<Text>(find.byKey(ProductCard.etaBadgeKey)).data, '30–35 د');
      expect(find.text('لتر'), findsOneWidget);
    });

    testWidgets('full price: no tag and no struck-through price', (tester) async {
      await pumpCard(tester, _product('p', price: 2));
      expect(find.byKey(ProductCard.discountTagKey), findsNothing);
      expect(find.text('2.000 د.أ'), findsOneWidget);
    });

    testWidgets('"أضف" becomes a "− 1 +" control, and back', (tester) async {
      await pumpCard(tester, _product('p', price: 2));
      expect(find.byKey(ProductCard.addKey), findsOneWidget);
      expect(find.text('أضف'), findsOneWidget);

      await tester.tap(find.byKey(ProductCard.addKey));
      await tester.pump();
      expect(find.byKey(ProductCard.addKey), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(container.read(cartItemCountProvider), 1);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(container.read(cartItemCountProvider), 2);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.byKey(ProductCard.addKey), findsOneWidget);
      expect(container.read(cartItemCountProvider), 0);
    });

    testWidgets('out of stock: covered, with no add control', (tester) async {
      await pumpCard(tester, const Product(id: 'x', categoryId: 'c1', name: 'n', nameAr: 'نافد', price: 2, stockStatus: StockStatus.outOfStock));
      expect(find.text('غير متوفر'), findsOneWidget);
      expect(find.byKey(ProductCard.addKey), findsNothing);
    });

    testWidgets('no zone information yet: no delivery-time badge, the rest still shows', (tester) async {
      await pumpCard(tester, _product('p', unit: 'كيلو'), zones: const []);
      // the address is selected but its zone is not in the (empty) list
      expect(find.byKey(ProductCard.etaBadgeKey), findsNothing);
      expect(find.text('كيلو'), findsOneWidget);
    });
  });

  group('floating cart bar', () {
    late ProviderContainer container;
    var viewed = 0;

    Future<void> pumpBar(WidgetTester tester) async {
      viewed = 0;
      container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(null),
        cartRepositoryProvider.overrideWithValue(_FakeCartRepository()),
        categoriesProvider.overrideWith((ref) async => const []),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(16), child: FloatingCartBar(onViewCart: () => viewed++)))),
          ),
        ),
      ));
    }

    testWidgets('empty cart: nothing is shown', (tester) async {
      await pumpBar(tester);
      expect(find.text('عرض السلة'), findsNothing);
    });

    testWidgets('count, total, what the discounts saved and a "view cart" button', (tester) async {
      await pumpBar(tester);
      container.read(cartProvider.notifier).add(_product('a', price: 5, discount: 4)); // saves 1.000
      container.read(cartProvider.notifier).add(_product('a', price: 5, discount: 4)); // ... twice: 2.000
      container.read(cartProvider.notifier).add(_product('b', price: 3));
      await tester.pump();
      expect(find.text('3 منتجات · 11.000 د.أ'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(FloatingCartBar.savingsKey)).data, 'وفّرت 2.000 د.أ');
      expect(container.read(cartSavingsProvider), 2.0);

      await tester.tap(find.text('عرض السلة'));
      expect(viewed, 1);
    });

    testWidgets('no discounts: shows how far the free-delivery goal is, then that it is reached', (tester) async {
      await pumpBar(tester);
      container.read(cartProvider.notifier).add(_product('a', price: 8));
      await tester.pump();
      expect(find.byKey(FloatingCartBar.savingsKey), findsNothing);
      expect(find.text('1 منتج · 8.000 د.أ'), findsOneWidget);
      expect(find.text('أضف 12.000 د.أ لتوصيل مجاني'), findsOneWidget);

      container.read(cartProvider.notifier).setQuantity(_product('a', price: 8), 3); // 24.000
      await tester.pump();
      expect(find.text('التوصيل مجاني 🎉'), findsOneWidget);
    });

    testWidgets('at most three little pictures, however many things are in the cart', (tester) async {
      await pumpBar(tester);
      for (var i = 0; i < 6; i++) {
        container.read(cartProvider.notifier).add(_product('p$i'));
      }
      await tester.pump();
      expect(find.byType(PositionedDirectional), findsNWidgets(3));
    });
  });
}

/// Addresses preloaded into state, without the sync-to-server path of a real save.
class _Preset extends SavedAddressesNotifier {
  _Preset(super.ref, List<SavedAddress> addresses) {
    state = addresses;
  }
}
