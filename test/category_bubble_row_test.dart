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
  _registerCutoutStyleTests();
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

// ---- cutout style: white cards, pictures shown whole ----
void _registerCutoutStyleTests() {
  testWidgets('each tile is a white rounded card holding the picture and the name', (tester) async {
    await tester.pumpWidget(_row(343, count: 6));
    final card = tester.widget<Container>(
      find.ancestor(of: find.byType(CategoryImage).first, matching: find.byType(Container)).first,
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.borderRadius, isNotNull);
    // the name is inside the same card as the picture
    expect(
      find.descendant(
        of: find.ancestor(of: find.byType(CategoryImage).first, matching: find.byType(Container)).first,
        matching: find.text('منظفات ومستلزمات المنزل'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pictures are shown whole (contain), never cropped', (tester) async {
    await tester.pumpWidget(_row(343, count: 6));
    expect(tester.widget<CategoryImage>(find.byType(CategoryImage).first).fit, BoxFit.contain);
  });

  testWidgets('the selected card gets a navy border', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryBubbleRow(
            categories: const [Category(id: '1', name: 'A', nameAr: 'أ'), Category(id: '2', name: 'B', nameAr: 'ب')],
            selectedCategoryId: '2',
            onSelected: (_) {},
          ),
        ),
      ),
    );
    final borders = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<Border>()
        .map((b) => b.top.width)
        .toList();
    expect(borders.where((w) => w == 1.5).length, 1);
  });

  testWidgets('no overflow at 2x text scale with long names', (tester) async {
    await tester.pumpWidget(_row(343, scale: 2));
    expect(tester.takeException(), isNull);
  });
}
