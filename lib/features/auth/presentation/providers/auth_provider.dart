import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Signing in with Google is optional everywhere: browsing, the cart and
/// checkout all work as a guest (an order needs only a name and phone).
///
/// Route to return to once sign-in actually completes, set by whatever
/// screen sent the user to `/login` because the action they tried (e.g.
/// checkout) needs a real account. Normally unused — main.dart pops back to
/// the pushing screen — but it's the fallback when there's nothing to pop
/// (web, where the OAuth redirect reloads the page). Consumed — and cleared — by the
/// sign-in listener in `main.dart`'s `AswaqAltaibatApp`, which is what
/// navigates once `currentUserProvider` actually flips to non-null; the
/// login screen itself doesn't navigate on success.
final pendingRedirectProvider = StateProvider<String?>((ref) => null);

/// Debug-only (set by LoginPage's "تسجيل دخول تجريبي" button, behind its
/// `kDebugMode` gate): a local-only "treat me as signed in" flag so the
/// checkout/location-picker UI can be reached and tested without a
/// configured Google provider. This is **not** a
/// real session — `currentUserProvider` (the real Supabase `auth.uid()`)
/// stays null, so RLS still blocks actually placing an order or syncing
/// cart_items. Read only by UI-level navigation gates (cart_page); every
/// repository that writes to Supabase keeps using `currentUserProvider`.
