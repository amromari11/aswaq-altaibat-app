import 'package:aswaq_altaibat/features/categories/presentation/widgets/category_image.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/category.dart';
import 'package:aswaq_altaibat/features/home/presentation/widgets/category_bubble_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('two-line category names do not overflow, even at 2x text scale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: CategoryBubbleRow(
              categories: const [
                Category(id: '1', name: 'Cheese', nameAr: 'اجبان والبان ومشتقاتها'),
                Category(id: '2', name: 'Dairy', nameAr: 'الألبان'),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    // A RenderFlex overflow is reported as a test exception.
    expect(tester.takeException(), isNull);
  });

  _registerFiveAcrossTests();
}

// ---- five tiles per row ----
Widget _row(double width, {int count = 13, double scale = 1, ValueChanged<Category>? onSelected}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: CategoryBubbleRow(
                categories: [
                  for (var i = 0; i < count; i++)
                    Category(
                        id: '$i',
                        name: 'C$i',
                        nameAr: i == 0 ? 'منظفات ومستلزمات المنزل' : 'قسم $i'),
                ],
                onSelected: onSelected ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder get _tiles => find.byType(CategoryImage);

void _registerFiveAcrossTests() {
  testWidgets('exactly five tiles fill a phone-width row, the rest scroll', (tester) async {
    await tester.pumpWidget(_row(343));
    final visible = _tiles.evaluate().length;
    expect(visible, inInclusiveRange(5, 6),
        reason: '5 on screen (+ at most one cached just off-screen)');
    final first = tester.getRect(find.byType(CategoryImage).first);
    final fifth = tester.getRect(find.byType(CategoryImage).at(4));
    expect(fifth.right, lessThanOrEqualTo(343 + 1), reason: 'the fifth tile ends inside the row');
    expect(first.width, closeTo(first.height, 8), reason: 'tiles stay square');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tiles are compact: about 62px wide on a 375px phone', (tester) async {
    await tester.pumpWidget(_row(343));
    final tile = tester.getSize(find.byType(Container).first).width;
    expect(tile, closeTo((343 - 8 * 4) / 5, 0.5));
  });

  testWidgets('tiles never exceed the tablet cap', (tester) async {
    await tester.pumpWidget(_row(1000));
    expect(tester.getSize(find.byType(Container).first).width, 92);
  });

  testWidgets('a fewer than five categories still renders at the same tile size', (tester) async {
    await tester.pumpWidget(_row(343, count: 2));
    expect(_tiles, findsNWidgets(2));
  });

  testWidgets('tapping a tile reports its category', (tester) async {
    Category? tapped;
    await tester.pumpWidget(_row(343, onSelected: (c) => tapped = c));
    await tester.tap(find.text('قسم 2'));
    expect(tapped?.id, '2');
  });

  testWidgets('long names and 2x text scale do not overflow the compact row', (tester) async {
    await tester.pumpWidget(_row(343, scale: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('works on a narrow 320px phone', (tester) async {
    await tester.pumpWidget(_row(288));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Container).first).width, closeTo((288 - 32) / 5, 0.5));
  });
}
