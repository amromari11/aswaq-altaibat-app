import 'package:aswaq_altaibat/features/categories/presentation/pages/categories_page.dart';
import 'package:aswaq_altaibat/features/categories/presentation/providers/selected_category_provider.dart';
import 'package:aswaq_altaibat/features/categories/presentation/widgets/category_card.dart';
import 'package:aswaq_altaibat/features/categories/presentation/widgets/category_image.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/category.dart';
import 'package:aswaq_altaibat/features/home/presentation/providers/home_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// No imageUrl on purpose: no network in tests, so every card shows its icon.
const _cats = [
  Category(id: '1', name: 'Cheese', nameAr: 'اجبان والبان ومشتقاتها'),
  Category(id: '2', name: 'Dairy', nameAr: 'الألبان'),
];

Widget _app(ProviderContainer container, {double textScale = 1}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const CategoriesPage()),
    GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
  ]);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  );
}

ProviderContainer _container(Future<List<Category>> Function() load) {
  final c = ProviderContainer(overrides: [categoriesProvider.overrideWith((_) => load())]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('shows a card per category', (tester) async {
    await tester.pumpWidget(_app(_container(() async => _cats)));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCard), findsNWidgets(2));
    expect(find.text('الألبان'), findsOneWidget);
  });

  testWidgets('a category without a picture shows the icon', (tester) async {
    await tester.pumpWidget(_app(_container(() async => _cats)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.local_grocery_store_outlined), findsNWidgets(2));
  });

  testWidgets('long names do not overflow at 2x text scale', (tester) async {
    await tester.pumpWidget(_app(_container(() async => _cats), textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a card selects the category and goes to Home', (tester) async {
    final container = _container(() async => _cats);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الألبان'));
    await tester.pumpAndSettle();
    expect(container.read(selectedCategoryProvider), '2');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('empty list says so', (tester) async {
    await tester.pumpWidget(_app(_container(() async => const [])));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد أقسام حالياً'), findsOneWidget);
  });

  testWidgets('error offers a retry that reloads', (tester) async {
    var calls = 0;
    final container = _container(() async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return _cats;
    });
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل الأقسام'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryCard), findsNWidgets(2));
  });

  testWidgets('CategoryImage treats an empty url as no picture', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoryImage(imageUrl: '')));
    expect(find.byIcon(Icons.local_grocery_store_outlined), findsOneWidget);
  });
}
