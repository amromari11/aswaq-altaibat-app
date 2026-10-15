import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../home/domain/entities/product.dart';
import '../../domain/entities/cart_item.dart';

/// Cart state lives client-side (Riverpod) until checkout, when it's sent to
/// Supabase as an `orders` row + `order_items` rows — there's no
/// server-side "in progress cart" table in the backend schema, matching how
/// most Q-commerce apps treat an unsubmitted cart as local/ephemeral state.
class CartNotifier extends StateNotifier<Map<String, CartItem>> {
  CartNotifier() : super(const {});

  void add(Product product) {
    final existing = state[product.id];
    state = {
      ...state,
      product.id: existing == null
          ? CartItem(product: product, quantity: 1)
          : existing.copyWith(quantity: existing.quantity + 1),
    };
  }

  void decrement(Product product) {
    final existing = state[product.id];
    if (existing == null) return;

    if (existing.quantity <= 1) {
      remove(product);
      return;
    }

    state = {
      ...state,
      product.id: existing.copyWith(quantity: existing.quantity - 1),
    };
  }

  void remove(Product product) {
    final next = {...state}..remove(product.id);
    state = next;
  }

  void clear() => state = const {};

  int quantityOf(String productId) => state[productId]?.quantity ?? 0;
}

final cartProvider =
    StateNotifierProvider<CartNotifier, Map<String, CartItem>>((ref) {
  return CartNotifier();
});

final cartItemsListProvider = Provider<List<CartItem>>((ref) {
  return ref.watch(cartProvider).values.toList();
});

final cartItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartProvider).values;
  return items.fold<int>(0, (sum, item) => sum + item.quantity);
});

final cartSubtotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider).values;
  return items.fold<double>(0, (sum, item) => sum + item.lineTotal);
});

/// JOD still needed to unlock free delivery, or 0 if already qualified.
final freeDeliveryRemainingProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final remaining = AppConfig.freeDeliveryThresholdJod - subtotal;
  return remaining > 0 ? remaining : 0;
});
