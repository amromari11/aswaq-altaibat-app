// Smoke test: the app boots to the splash screen (scooter animation +
// slogan), then goes straight to Home — no forced login.
//
// Deliberately does not call Supabase.initialize() (that's main()'s job, and
// needs network): the Supabase client is swapped for one pointed at an
// unreachable local address, so Home's data providers just land in their
// error states instead of hitting the real project.

import 'package:aswaq_altaibat/core/router/app_router.dart';
import 'package:aswaq_altaibat/core/supabase/supabase_providers.dart';
import 'package:aswaq_altaibat/features/splash/presentation/pages/splash_page.dart';
import 'package:aswaq_altaibat/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('App boots to splash with the slogan, then goes straight to home', (tester) async {
    final container = ProviderContainer(overrides: [
      supabaseClientProvider.overrideWithValue(SupabaseClient(
        'http://127.0.0.1:9',
        'test-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      )),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AswaqAltaibatApp()),
    );
    await tester.pump();

    expect(find.text('أسواق الطيبات'), findsOneWidget);
    expect(find.text(slogan.replaceFirst(': ', ':\n')), findsOneWidget);

    // Splash waits 2500ms before navigating — see splash_page.dart.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();

    final location = container.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path;
    expect(location, '/home');
    expect(find.text('تسجيل الدخول'), findsNothing);
  });
}
