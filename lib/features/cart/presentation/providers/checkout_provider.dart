import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/checkout_repository.dart';
import 'cart_provider.dart';

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(supabaseClientProvider));
});

/// Thrown when a pre-checkout stock re-check finds the cart no longer
/// matches reality (someone else bought the last of it, an admin marked it
/// out of stock, etc). [issues] is never empty when this is thrown.
class OutOfStockException implements Exception {
  OutOfStockException(this.issues);

  final List<StockIssue> issues;
}

class CheckoutController extends StateNotifier<AsyncValue<void>> {
  CheckoutController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Guests and signed-in customers order the same way: [customerName] and
  /// [customerPhone] (E.164) identify who it's for; no account is needed.
  Future<String?> placeOrder({
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String zoneId,
    double? deliveryLat,
    double? deliveryLng,
    String? notes,
    String? addressId,
    String? trackingToken,
  }) async {
    final items = _ref.read(cartItemsListProvider);
    if (items.isEmpty) return null;

    state = const AsyncValue.loading();
    try {
      final issues = await _ref.read(checkoutRepositoryProvider).checkStock(items);
      if (issues.isNotEmpty) {
        // Reconcile the cart to what's actually available, so the next
        // attempt (after the user sees why this one failed) can succeed.
        final cartNotifier = _ref.read(cartProvider.notifier);
        for (final issue in issues) {
          cartNotifier.setQuantity(issue.product, issue.availableQuantity);
        }
        state = AsyncValue.error(OutOfStockException(issues), StackTrace.current);
        return null;
      }

      final orderId = await _ref.read(checkoutRepositoryProvider).placeOrder(
            customerName: customerName,
            customerPhone: customerPhone,
            items: items,
            deliveryAddress: deliveryAddress,
            zoneId: zoneId,
            addressId: addressId,
            deliveryLat: deliveryLat,
            deliveryLng: deliveryLng,
            notes: notes,
            trackingToken: trackingToken,
          );
      _ref.read(cartProvider.notifier).clear();
      state = const AsyncValue.data(null);
      return orderId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}

final checkoutControllerProvider = StateNotifierProvider<CheckoutController, AsyncValue<void>>((ref) {
  return CheckoutController(ref);
});
