# أسواق الطيبات — Mobile App

Flutter client for Aswaq Altaibat (Zarqa, Jordan), backed by the Supabase
project in `../aswaq-altaibat-backend`.

## Status

This is the initial scaffold: project structure, theming, routing, and a
fully wired Home screen (categories, weekly offers, order-again, sponsored
banners, cart) plus a Google sign-in screen. Checkout, full category browsing,
order history, and account details beyond sign-out are stubbed — see the
`// TODO` comments in `lib/features/*`.

**The Flutter SDK is not installed on the machine this was written on**, so
none of this has been run through `flutter analyze`, `flutter pub get`, or
an actual build — only read carefully against the Flutter/package APIs it
uses. Treat the first `flutter pub get` + `flutter run` as the real test.

## First-time setup

```bash
# 1. Install the Flutter SDK if you haven't: https://docs.flutter.dev/get-started/install

# 2. From this directory, generate the native platform folders
#    (android/, ios/, etc. — not committed, see .gitignore):
flutter create . --org com.aswaqaltaibat --project-name aswaq_altaibat

# 3. Install dependencies
flutter pub get

# 4. Fill in lib/core/config/app_config.dart:
#    - supabaseAnonKey (Supabase dashboard → Settings → API → "anon public")
#    - double-check supabaseUrl against the same page while you're there

# 5. Run
flutter run
```

## Backend dependency

Two things need to exist on the Supabase project before the app will show
real data:

1. `supabase/schema.sql` and `supabase/002_notifications.sql` from the admin
   dashboard repo (categories, products, orders, etc.) — already applied if
   you've been using the admin dashboard.
2. `supabase/003_sponsors.sql` (also in the backend repo) — new tables
   (`sponsors_banners`, `promoted_products`) this app's sponsors feature
   reads from. **Run this one before testing the Home screen's banner
   carousel**, or it'll just show no banners (handled gracefully, not a
   crash — `homeBannersProvider`'s error state renders nothing).

Sign-in is Google only (SMS OTP was dropped for cost). It needs:
- Authentication → Providers → Google enabled in Supabase, with a Google
  Cloud OAuth client ID/secret (authorized redirect URI:
  `https://<project-ref>.supabase.co/auth/v1/callback`).
- Authentication → URL Configuration → Redirect URLs containing
  `com.aswaqaltaibat.app://login-callback` (iOS/Android) and the web
  origin(s) you run on, e.g. `http://localhost:*/**`.
- The same `com.aswaqaltaibat.app` scheme registered in
  `ios/Runner/Info.plist` (CFBundleURLTypes) and
  `android/app/src/main/AndroidManifest.xml` (intent-filter) — these
  folders aren't committed, so re-add it after `flutter create .`.

Phone numbers aren't verified: customers type the number twice (checkout or
Account → رقم الهاتف), it must be a Jordanian mobile (077/078/079), and it's
saved to `profiles.phone_number`, which the admin dashboard's orders page
shows.

## Project structure

```
lib/
  core/             # Shared: theme, router, Supabase client, widgets, utils
  features/
    splash/
    auth/           # Google sign-in, guest mode
    home/           # Home screen: categories, products, banners, search
    cart/           # Client-side cart state (not persisted until checkout)
    sponsors/       # Sponsored banners & promoted products (retail media)
    categories/      # Stub — full category browser
    offers/          # Stub — full weekly-offers page
    orders/           # Stub — order history
    account/          # Sign-in state, sign-out
```

Each feature under `lib/features/` follows `domain/` (entities) →
`data/` (Supabase-backed repositories) → `presentation/` (Riverpod
providers, pages, widgets) — Clean Architecture, feature-first.

## Notes on specific choices

- **State management:** Riverpod, not Provider — picked because
  `FutureProvider`/`StateNotifierProvider` map directly onto
  "fetch from Supabase" and "client-side cart state" without extra
  ChangeNotifier boilerplate per feature.
- **Routing:** `go_router` with `StatefulShellRoute` for the bottom nav, so
  each tab keeps its own navigation stack.
- **Currency:** Jordanian Dinar formats to **3 decimal places** (1 JOD =
  1000 fils) — see `lib/core/utils/currency_formatter.dart`. The backend's
  `numeric(10,2)` price columns need a migration to `numeric(10,3)` for this
  to be lossless; see `003_sponsors.sql`'s sibling note in the backend repo.
- **Splash Lottie:** `lottie` is a dependency and the splash screen has a
  marked spot to drop in a real animation, but no `.json` file is bundled
  yet (a missing asset reference would crash the app) — see the comment at
  the top of `lib/features/splash/presentation/pages/splash_page.dart`.
