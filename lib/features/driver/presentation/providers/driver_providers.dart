import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/driver_repository.dart';
import '../../domain/entities/driver_order.dart';
import '../../domain/entities/driver_profile.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's role and availability; [DriverProfile.customer] when
/// signed out. Re-fetches when the user changes.
final driverProfileProvider = FutureProvider<DriverProfile>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return DriverProfile.customer;
  return ref.watch(driverRepositoryProvider).fetchProfile(user.id);
});

/// True once the profile has loaded and says "driver".
final isDriverProvider = Provider<bool>((ref) {
  return ref.watch(driverProfileProvider).valueOrNull?.isDriver ?? false;
});

/// The "متاح للتوصيل" switch. Flips immediately and rolls back if the
/// database refuses, so the admin's live view and the switch never disagree
/// for longer than one round trip.
class DriverAvailabilityNotifier extends AutoDisposeAsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final profile = await ref.watch(driverProfileProvider.future);
    return profile.isAvailable;
  }

  /// Throws [DriverActionException] (after restoring the old value) on failure.
  Future<void> set(bool available) async {
    final previous = state.valueOrNull ?? !available;
    state = AsyncData(available);
    try {
      state = AsyncData(await ref.read(driverRepositoryProvider).setAvailable(available));
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// The database changed it for us (a pick-up pauses it, the last delivery
  /// switches it back on).
  void sync(bool available) => state = AsyncData(available);
}

final driverAvailabilityProvider = AutoDisposeAsyncNotifierProvider<DriverAvailabilityNotifier, bool>(
  DriverAvailabilityNotifier.new,
);

/// The driver's active orders. Refreshes on its own when the shop assigns or
/// re-assigns an order (Realtime ping), every [_fallbackRefresh] in case a
/// ping is lost, and after every action.
class DriverOrdersNotifier extends AutoDisposeAsyncNotifier<List<DriverOrder>> {
  static const _fallbackRefresh = Duration(minutes: 1);

  @override
  Future<List<DriverOrder>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    final repo = ref.watch(driverRepositoryProvider);

    final sub = repo.changes(user.id).listen((_) => refresh());
    final timer = Timer.periodic(_fallbackRefresh, (_) => refresh());
    ref.onDispose(() {
      sub.cancel();
      timer.cancel();
    });

    return repo.fetchAssignedOrders();
  }

  /// Re-reads the list, keeping the current one on screen meanwhile; a failed
  /// background refresh keeps the last good list instead of an error screen.
  Future<void> refresh() async {
    try {
      final orders = await ref.read(driverRepositoryProvider).fetchAssignedOrders();
      state = AsyncData(orders);
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
    }
  }

  Future<void> pickUp(String orderId) async {
    await ref.read(driverRepositoryProvider).pickUp(orderId);
    await refresh();
    // A pick-up pauses availability on the server; re-read it.
    ref.invalidate(driverProfileProvider);
  }

  Future<DeliveryResult> markDelivered(String orderId) async {
    final result = await ref.read(driverRepositoryProvider).markDelivered(orderId);
    ref.read(driverAvailabilityProvider.notifier).sync(result.available);
    await refresh();
    return result;
  }
}

final driverOrdersProvider = AutoDisposeAsyncNotifierProvider<DriverOrdersNotifier, List<DriverOrder>>(
  DriverOrdersNotifier.new,
);
