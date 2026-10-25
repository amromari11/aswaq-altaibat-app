import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/notifications/local_notifications_service.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/cart/presentation/providers/cart_abandonment_provider.dart';
import 'features/cart/presentation/providers/cart_provider.dart';
import 'features/location/presentation/providers/location_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // Still the anon/public key — `publishableKey` is just this version of
    // supabase_flutter's current parameter name for it (anonKey is
    // deprecated but holds the same value).
    publishableKey: AppConfig.supabaseAnonKey,
  );

  // Notification permission can be denied by the user or unavailable on a
  // given platform/emulator — never let that block the app from starting.
  try {
    await LocalNotificationsService.instance.initialize();
  } catch (_) {
    // Abandoned-cart reminders just won't fire this session; everything
    // else works fine without them.
  }

  // Created manually (rather than a plain `ProviderScope`) so an
  // already-authenticated cold start — a restored Supabase session — can
  // pull the saved cart down before the first frame. `ref.listen` inside a
  // widget's build only fires on *changes*, so it can't see this case on
  // its own; see the sign-in/sign-out listener in AswaqAltaibatApp.build.
  final container = ProviderContainer();
  if (container.read(currentUserProvider) != null) {
    unawaited(container.read(cartProvider.notifier).hydrateFromServer());
    unawaited(container.read(savedAddressesProvider.notifier).hydrateFromServer());
  }

  runApp(UncontrolledProviderScope(container: container, child: const AswaqAltaibatApp()));
}

class AswaqAltaibatApp extends ConsumerWidget {
  const AswaqAltaibatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Alive for the app's lifetime — see the provider's own doc comment.
    ref.watch(cartAbandonmentWatcherProvider);

    // Sign-in during the session pulls the user's saved cart down from
    // Supabase (the already-authenticated-at-launch case is handled once in
    // main(), above) and — this is the single place that navigates after a
    // successful sign-in, for every auth method (phone OTP, Google, any
    // future one) — returns to whatever screen sent the user to /login in
    // the first place (e.g. checkout), via pendingRedirectProvider, or
    // /home if they got to /login on their own. The login/OTP pages
    // themselves don't navigate on success; they just wait for this.
    // Sign-out clears local cart state only, without touching the saved
    // server-side cart.
    ref.listen<User?>(currentUserProvider, (previous, next) {
      if (previous == null && next != null) {
        ref.read(cartProvider.notifier).hydrateFromServer();
        ref.read(savedAddressesProvider.notifier).hydrateFromServer();
        final redirectTo = ref.read(pendingRedirectProvider);
        ref.read(pendingRedirectProvider.notifier).state = null;
        ref.read(appRouterProvider).go(redirectTo ?? '/home');
      } else if (previous != null && next == null) {
        ref.read(cartProvider.notifier).clearLocalOnly();
        ref.read(savedAddressesProvider.notifier).clearLocalOnly();
        ref.read(selectedAddressIdProvider.notifier).state = null;
      }
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      // Global*, not Default* — Default* only ever renders English
      // regardless of `locale`/`supportedLocales`. This app needs real
      // Arabic strings for built-in widgets (date pickers, dialog
      // buttons, text-selection toolbar, ...).
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // RTL app-wide regardless of device locale — Aswaq Altaibat is
        // Arabic-first, not a localized-by-device-setting app.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
