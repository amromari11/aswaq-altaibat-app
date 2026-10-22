// Smoke test: the app boots to the splash screen, then navigates to login
// once the splash timer fires, without throwing.
//
// Deliberately does not call Supabase.initialize() (that's main()'s job,
// and needs network) — it pumps the root widget directly, the same way
// main() does after initialization, relying on the initial /splash and
// /login routes touching no Supabase-backed provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aswaq_altaibat/main.dart';

void main() {
  testWidgets('App boots to splash, then navigates to login', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AswaqAltaibatApp()),
    );
    await tester.pump();

    expect(find.text('أسواق الطيبات'), findsOneWidget);

    // Let the splash screen's navigation Timer fire (and get fully
    // consumed) instead of leaving it pending at test teardown. Splash
    // waits 2500ms before navigating — see splash_page.dart.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();

    expect(find.text('تسجيل الدخول'), findsWidgets);
  });
}
