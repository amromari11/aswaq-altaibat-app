import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../home/domain/entities/product.dart';
import '../../data/repositories/cart_repository.dart';
import '../../domain/entities/cart_item.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(supabaseClientProvider));
});

/// Cart state lives client-side (Riverpod) as the source of truth for the
/// current session, and is mirrored to `cart_items` in Supabase for
/// signed-in users only (guests stay local-only — RLS needs a `user_id`).
/// Submitted carts still become an `orders` row + `order_items` rows at
/// checkout, same as before; `cart_items` is just "what's still in the
/// cart", not order history.
class CartNotifier extends StateNotifier<Map<String, CartItem>> {
  CartNotifier(this._ref) : super(const {});

  final Ref _ref;

  CartRepository get _repository => _ref.read(cartRepositoryProvider);
  String? get _userId => _ref.read(currentUserProvider)?.id;

  /// Returns false (and leaves the cart unchanged) if [product] is out of
  /// stock, or already in the cart at its full available quantity —
  /// callers show the user why the tap did nothing.
  bool add(Product product) {
    final existing = state[product.id];
    final currentQuantity = existing?.quantity ?? 0;

    if (product.isOutOfStock) return false;
    // stockQuantity == 0 with a non-"out_of_stock" status means the catalog
    // row just isn't tracking a count — treat that as unlimited rather than
    // blocking every add.
    if (product.stockQuantity > 0 && currentQuantity >= product.stockQuantity) {
      return false;
    }

    final newQuantity = currentQuantity + 1;
    state = {
      ...state,
      product.id: existing == null
          ? CartItem(product: product, quantity: 1)
          : existing.copyWith(quantity: newQuantity),
    };
    _syncUpsert(product.id, newQuantity);
    return true;
  }

  void decrement(Product product) {
    final existing = state[product.id];
    if (existing == null) return;

    if (existing.quantity <= 1) {
      remove(product);
      return;
    }

    final newQuantity = existing.quantity - 1;
    state = {
      ...state,
      product.id: existing.copyWith(quantity: newQuantity),
    };
    _syncUpsert(product.id, newQuantity);
  }

  void remove(Product product) {
    final next = {...state}..remove(product.id);
    state = next;
    _syncDelete(product.id);
  }

  /// Sets an exact quantity for [product] (removing it if [quantity] <= 0).
  /// Used to reconcile the cart against a checkout-time stock re-check —
  /// see [CheckoutRepository.checkStock].
  void setQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      remove(product);
      return;
    }
    state = {...state, product.id: CartItem(product: product, quantity: quantity)};
    _syncUpsert(product.id, quantity);
  }

  void clear() {
    state = const {};
    _syncClear();
  }

  /// Resets only the in-memory cart, without touching the server copy —
  /// used on sign-out, so the next guest/account on this device doesn't see
  /// a leftover cart. (Calling [clear] instead would delete the signed-out
  /// user's saved cart_items, which isn't what signing out means.)
  void clearLocalOnly() => state = const {};

  int quantityOf(String productId) => state[productId]?.quantity ?? 0;

  /// Merges the signed-in user's saved cart from Supabase into local state.
  /// Called on sign-in (including an already-authenticated app launch) so a
  /// cart started on another device or a previous session reappears.
  ///
  /// Sign-in now happens at the *end* of checkout, so the local cart is
  /// usually the guest cart the customer is about to order — it must
  /// survive. Local lines win over server lines for the same product (they're
  /// the latest choice) and are written back so the server copy matches.
  Future<void> hydrateFromServer() => _hydration = _hydrate();

  /// Completes when the latest [hydrateFromServer] has finished, so a
  /// checkout resumed right after sign-in places the order only once the
  /// merged cart has been written back (otherwise a late write-back could
  /// re-add the just-ordered items after the order clears the cart).
  Future<void> get hydrationDone => _hydration ?? Future.value();
  Future<void>? _hydration;

  Future<void> _hydrate() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final serverItems = await _repository.fetchCart(userId);
      final local = state;
      state = {
        for (final item in serverItems) item.product.id: item,
        ...local,
      };
      await Future.wait([
        for (final item in local.values)
          _repository.upsertItem(userId, item.product.id, item.quantity).catchError((_) {}),
      ]);
    } catch (_) {
      // Persistence is a convenience, not the source of truth for the
      // current session — keep whatever local state already exists.
    }
  }

  void _syncUpsert(String productId, int quantity) {
    final userId = _userId;
    if (userId == null) return;
    unawaited(_repository.upsertItem(userId, productId, quantity).catchError((_) {}));
  }

  void _syncDelete(String productId) {
    final userId = _userId;
    if (userId == null) return;
    unawaited(_repository.deleteItem(userId, productId).catchError((_) {}));
  }

  void _syncClear() {
    final userId = _userId;
    if (userId == null) return;
    unawaited(_repository.clearCart(userId).catchError((_) {}));
  }
}

final cartProvider =
    StateNotifierProvider<CartNotifier, Map<String, CartItem>>((ref) {
  return CartNotifier(ref);
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
