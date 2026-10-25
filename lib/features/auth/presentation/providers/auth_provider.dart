import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Everyone browses as a guest by default; the only place that requires an
/// account is confirming an order at checkout.
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
/// Set by checkout when a guest's "تأكيد الطلب" sends them to sign in: once
/// the sign-in lands back on that checkout, it places the order by itself so
/// the customer doesn't tap confirm twice. Cleared when it's consumed, or
/// when the customer backs out of the login screen instead.
final resumeCheckoutAfterSignInProvider = StateProvider<bool>((ref) => false);

final isMockSignedInProvider = StateProvider<bool>((ref) => false);
