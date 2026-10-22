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
}
