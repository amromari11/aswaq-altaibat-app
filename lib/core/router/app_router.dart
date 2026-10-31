import '../../features/search/presentation/pages/barcode_scan_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/pages/account_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
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
import '../../features/orders/domain/entities/order_ref.dart';
import '../../features/orders/presentation/pages/my_orders_page.dart';
import '../../features/orders/presentation/pages/order_tracking_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutPage()),
      // The token rides in the query string (not `extra`) so the link still
      // works after a browser reload.
      GoRoute(
        path: '/order/:id',
        builder: (context, state) => OrderTrackingPage(
          orderRef: OrderRef(id: state.pathParameters['id']!, token: state.uri.queryParameters['t'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/addresses',
        builder: (context, state) => SavedAddressesPage(pickMode: state.extra == true),
      ),
      GoRoute(
        path: '/address-form',
        builder: (context, state) => AddressFormPage(existing: state.extra as SavedAddress?),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const BarcodeScanPage(),
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
