import 'package:aswaq_altaibat/features/categories/presentation/widgets/category_image.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/category.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/product.dart';
import 'package:aswaq_altaibat/features/home/presentation/providers/home_providers.dart';
import 'package:aswaq_altaibat/features/home/presentation/widgets/product_card.dart';
import 'package:aswaq_altaibat/features/home/presentation/widgets/product_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _dairyUrl = 'https://img.test/dairy.webp';
const _categories = [
  Category(id: 'dairy', name: 'Dairy', nameAr: 'ألبان', imageUrl: _dairyUrl),
  Category(id: 'bare', name: 'Bare', nameAr: 'بلا صورة'),
];

Product _product({String category = 'dairy', String? image, double? discount}) => Product(
      id: 'p1',
      categoryId: category,
      name: 'Milk',
      nameAr: 'حليب كامل الدسم من الطيبات لتر',
      price: 1.25,
      discountPrice: discount,
      imageUrl: image,
      unit: 'لتر',
    );

Widget _app(Product product, {List<Category>? categories = _categories, double scale = 1}) {
  return ProviderScope(
    overrides: [
      categoriesProvider.overrideWith((_) async => categories ?? const <Category>[]),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(width: 180, height: 270, child: ProductCard(product: product)),
          ),
        ),
      ),
    ),
  );
}

/// The category picture's loading shimmer animates forever, so `pumpAndSettle` would never return.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('hasOwnImage is false for null and empty', () {
    expect(_product().hasOwnImage, isFalse);
    expect(_product(image: '').hasOwnImage, isFalse);
    expect(_product(image: 'https://x/a.webp').hasOwnImage, isTrue);
  });

  testWidgets('a product without a picture shows its category picture, marked illustrative',
      (tester) async {
    await tester.pumpWidget(_app(_product()));
    await _settle(tester);
    expect(find.byKey(ProductImage.fallbackKey), findsOneWidget);
    final image = tester.widget<CategoryImage>(find.byType(CategoryImage));
    expect(image.imageUrl, _dairyUrl);
    expect(find.text('صورة توضيحية'), findsOneWidget);
  });

  testWidgets('a product with its own picture does not use the fallback', (tester) async {
    await tester.pumpWidget(_app(_product(image: 'https://img.test/milk.webp')));
    await tester.pump();
    expect(find.byKey(ProductImage.fallbackKey), findsNothing);
    expect(find.text('صورة توضيحية'), findsNothing);
    final cached = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(cached.imageUrl, 'https://img.test/milk.webp');
    expect(cached.fit, BoxFit.contain, reason: 'product shots are shown whole, never cropped');
  });

  testWidgets(
      'a category with no picture falls back to a plain icon, without the illustrative label',
      (tester) async {
    await tester.pumpWidget(_app(_product(category: 'bare')));
    await _settle(tester);
    expect(find.byKey(ProductImage.fallbackKey), findsOneWidget);
    expect(find.byIcon(Icons.local_grocery_store_outlined), findsOneWidget);
    expect(find.text('صورة توضيحية'), findsNothing);
  });

  testWidgets('an unknown category (or categories not loaded) still renders a complete card',
      (tester) async {
    await tester.pumpWidget(_app(_product(category: 'ghost'), categories: const []));
    await _settle(tester);
    expect(find.byKey(ProductImage.fallbackKey), findsOneWidget);
    expect(find.text('حليب كامل الدسم من الطيبات لتر'), findsOneWidget);
  });

  testWidgets('the discount badge and price still show over the fallback', (tester) async {
    await tester.pumpWidget(_app(_product(discount: 1.0)));
    await _settle(tester);
    expect(find.textContaining('% OFF'), findsOneWidget);
    expect(find.byKey(ProductImage.fallbackKey), findsOneWidget);
  });

  testWidgets('no overflow at 1.3x text scale', (tester) async {
    await tester.pumpWidget(_app(_product(discount: 1.0), scale: 1.3));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
