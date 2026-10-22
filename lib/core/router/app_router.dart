import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/pages/account_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_verify_page.dart';
import '../../features/cart/presentation/pages/cart_page.dart';
import '../../features/cart/presentation/pages/checkout_page.dart';
import '../../features/categories/presentation/pages/categories_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/location/domain/entities/saved_address.dart';
import '../../features/location/presentation/pages/address_form_page.dart';
import '../../features/location/presentation/pages/location_picker_page.dart';
import '../../features/location/presentation/pages/osm_location_picker_page.dart';
import '../../features/location/presentation/pages/saved_addresses_page.dart';
import '../../features/offers/presentation/pages/offers_page.dart';
import '../../features/orders/presentation/pages/my_orders_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) => OtpVerifyPage(phone: state.extra as String),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutPage()),
      GoRoute(
        path: '/addresses',
        builder: (context, state) => SavedAddressesPage(pickMode: state.extra == true),
      ),
      GoRoute(
        path: '/address-form',
        builder: (context, state) => AddressFormPage(existing: state.extra as SavedAddress?),
      ),
      GoRoute(
        path: '/location-picker',
        builder: (context, state) => const LocationPickerPage(),
      ),
      GoRoute(
        path: '/location-picker-osm',
        builder: (context, state) => const OsmLocationPickerPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomePage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/categories', builder: (context, state) => const CategoriesPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/offers', builder: (context, state) => const OffersPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/orders', builder: (context, state) => const MyOrdersPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/account', builder: (context, state) => const AccountPage())],
          ),
        ],
      ),
    ],
  );
});
