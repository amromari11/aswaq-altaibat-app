import 'package:aswaq_altaibat/features/banners/domain/entities/promo_banner.dart';
import 'package:aswaq_altaibat/features/banners/presentation/banner_actions.dart';
import 'package:aswaq_altaibat/features/banners/presentation/widgets/promo_banner_carousel.dart';
import 'package:aswaq_altaibat/features/categories/presentation/providers/selected_category_provider.dart';
import 'package:aswaq_altaibat/features/home/data/repositories/home_repository.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/product.dart';
import 'package:aswaq_altaibat/features/home/presentation/providers/home_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

const _uuid = '123e4567-e89b-12d3-a456-426614174000';

PromoBanner _b(String id,
        {String? title, BannerTargetType type = BannerTargetType.none, String? target}) =>
    PromoBanner(
        id: id,
        imageUrl: 'https://img.test/$id.webp',
        title: title,
        targetType: type,
        targetId: target);

class _FakeHome implements HomeRepository {
  _FakeHome(this.product);
  final Product? product;
  @override
  Future<Product?> fetchProduct(String id) async => product;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _milk =
    Product(id: _uuid, categoryId: 'c1', name: 'Milk', nameAr: 'حليب كامل الدسم', price: 1.2);

void main() {
  group('PromoBanner.fromJson', () {
    test('reads the table row', () {
      final b = PromoBanner.fromJson({
        'id': 'b1',
        'title': '  خصومات  ',
        'image_url': 'https://x/a.webp',
        'target_type': 'category',
        'target_id': _uuid,
        'display_order': 2,
      });
      expect(b.title, 'خصومات');
      expect(b.targetType, BannerTargetType.category);
      expect(b.isTappable, isTrue);
      expect(b.displayOrder, 2);
    });

    test('blank title, unknown type and "none" are not tappable', () {
      final b = PromoBanner.fromJson(
          {'id': 'b', 'title': '  ', 'image_url': 'u', 'target_type': 'popup'});
      expect(b.title, isNull);
      expect(b.targetType, BannerTargetType.none);
      expect(b.isTappable, isFalse);
      expect(_b('x', type: BannerTargetType.link).isTappable, isFalse,
          reason: 'a link with no url');
    });
  });

  group('PromoBannerCarousel', () {
    Widget app(List<PromoBanner> banners, {ValueChanged<PromoBanner>? onTap, double scale = 1}) =>
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: PromoBannerCarousel(banners: banners, onBannerTap: onTap)),
            ),
          ),
        );

    testWidgets('shows the title and dots for several banners', (tester) async {
      await tester.pumpWidget(app([_b('1', title: 'خصومات يومية'), _b('2', title: 'توصيل سريع')]));
      expect(find.text('خصومات يومية'), findsOneWidget);
      expect(find.byType(AnimatedSmoothIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // stop the auto-play timer
    });

    testWidgets('one banner: no dots and no auto-play', (tester) async {
      await tester.pumpWidget(app([_b('1', title: 'واحد')]));
      expect(find.byType(AnimatedSmoothIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an empty list takes no space', (tester) async {
      await tester.pumpWidget(app(const []));
      expect(tester.getSize(find.byType(PromoBannerCarousel)).height, 0);
    });

    testWidgets('only a tappable banner reports taps', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(app(
          [_b('1', title: 'A', type: BannerTargetType.category, target: _uuid)],
          onTap: (b) => tapped.add(b.id)));
      await tester.tap(find.text('A'));
      expect(tapped, ['1']);
      await tester.pumpWidget(app([_b('2', title: 'B')], onTap: (b) => tapped.add(b.id)));
      await tester.tap(find.text('B'));
      expect(tapped, ['1']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a long title does not overflow at 2x text scale', (tester) async {
      await tester.pumpWidget(app(
          [_b('1', title: 'خصومات يومية كبيرة على جميع احتياجاتك من المواد الغذائية والمنزلية')],
          scale: 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('openBanner', () {
    late ProviderContainer container;
    late WidgetRef ref;

    Future<void> mount(WidgetTester tester, {Product? product}) async {
      container = ProviderContainer(
          overrides: [homeRepositoryProvider.overrideWithValue(_FakeHome(product))]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (context, r, _) {
          ref = r;
          return const SizedBox();
        }),
      ));
    }

    testWidgets('category: selects it and clears any search', (tester) async {
      await mount(tester);
      container.read(searchQueryProvider.notifier).state = 'old';
      expect(
          await openBanner(ref, _b('1', type: BannerTargetType.category, target: _uuid)), isTrue);
      expect(container.read(selectedCategoryProvider), _uuid);
      expect(container.read(searchQueryProvider), '');
    });

    testWidgets('product: searches for it by name and drops the category filter', (tester) async {
      await mount(tester, product: _milk);
      container.read(selectedCategoryProvider.notifier).state = 'c9';
      expect(await openBanner(ref, _b('1', type: BannerTargetType.product, target: _uuid)), isTrue);
      expect(container.read(searchQueryProvider), 'حليب كامل الدسم');
      expect(container.read(selectedCategoryProvider), isNull);
    });

    testWidgets('product that no longer exists: reports failure and changes nothing',
        (tester) async {
      await mount(tester);
      container.read(selectedCategoryProvider.notifier).state = 'c9';
      expect(
          await openBanner(ref, _b('1', type: BannerTargetType.product, target: _uuid)), isFalse);
      expect(container.read(selectedCategoryProvider), 'c9');
      expect(container.read(searchQueryProvider), '');
    });

    testWidgets('link: opens https only', (tester) async {
      await mount(tester);
      final opened = <Uri>[];
      Future<bool> fake(Uri u) async {
        opened.add(u);
        return true;
      }

      expect(
          await openBanner(
              ref, _b('1', type: BannerTargetType.link, target: 'https://example.com/offer'),
              launch: fake),
          isTrue);
      expect(
          await openBanner(ref, _b('2', type: BannerTargetType.link, target: 'http://example.com'),
              launch: fake),
          isFalse);
      expect(
          await openBanner(ref, _b('3', type: BannerTargetType.link, target: 'javascript:alert(1)'),
              launch: fake),
          isFalse);
      expect(opened.map((u) => u.toString()), ['https://example.com/offer']);
    });

    testWidgets('none / missing target does nothing', (tester) async {
      await mount(tester);
      expect(await openBanner(ref, _b('1')), isFalse);
      expect(await openBanner(ref, _b('2', type: BannerTargetType.category)), isFalse);
      expect(container.read(selectedCategoryProvider), isNull);
    });
  });
}
