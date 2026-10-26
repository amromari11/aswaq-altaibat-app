import 'dart:async';

import 'package:flutter_map/flutter_map.dart' show TileProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/local/my_orders_store.dart';
import '../../data/repositories/order_tracking_repository.dart';
import '../../domain/entities/order_change.dart';
import '../../domain/entities/order_ref.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/order_tracking.dart';

final orderTrackingRepositoryProvider = Provider<OrderTrackingRepository>((ref) {
  return OrderTrackingRepository(ref.watch(supabaseClientProvider));
});

/// Where the tracking map gets its tiles. Null = the default network provider;
/// tests override it so no tile requests leave the machine.
final orderMapTileProviderProvider = Provider<TileProvider?>((ref) => null);

/// How often tracking re-checks on its own. The live broadcast normally makes
/// this irrelevant (updates arrive instantly); it's the safety net for when
/// Realtime is down or the connection silently dropped.
final trackingPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 20));

/// One order, kept live: fetched immediately, then updated by the order's
/// Realtime channel — a status broadcast re-fetches, a driver broadcast moves
/// the driver straight away — and re-fetched on a slow timer as a fallback.
/// Emits `null` when the id/token don't match an order. A failed *first* fetch
/// is an error (the page offers retry); a failed refresh later keeps the last
/// good value on screen.
final orderTrackingProvider =
    StreamProvider.autoDispose.family<OrderTracking?, OrderRef>((ref, orderRef) async* {
  final repository = ref.watch(orderTrackingRepositoryProvider);
  final events = StreamController<OrderChange>();
  final live = repository.changes(orderRef).listen(events.add, onError: (_) {});
  final poll = Timer.periodic(
    ref.read(trackingPollIntervalProvider),
    (_) => events.add(const OrderRefreshNeeded()),
  );
  ref.onDispose(() {
    poll.cancel();
    live.cancel();
    events.close();
  });

  var current = await repository.fetchTracking(orderRef);
  yield current;

  await for (final event in events.stream) {
    try {
      switch (event) {
        case OrderRefreshNeeded():
          current = await repository.fetchTracking(orderRef);
          yield current;
        case DriverMoved(:final location):
          final order = current;
          // A ping only means something while the order is out for delivery,
          // and an older one that arrives late must not undo a newer position.
          if (order == null || order.status != OrderStatus.outForDelivery) break;
          final known = order.driver;
          if (known != null && location.updatedAt.isBefore(known.updatedAt)) break;
          current = order.withDriver(location);
          yield current;
      }
    } catch (_) {
      // Transient (offline, server hiccup): keep what's already on screen.
    }
  }
});

/// Everything for the orders list: this device's orders plus, for a signed-in
/// customer, their account's — de-duplicated, newest first.
final ordersListProvider = FutureProvider.autoDispose<List<OrderSummary>>((ref) async {
  final repository = ref.watch(orderTrackingRepositoryProvider);
  final local = await ref.watch(myOrderRefsProvider.future);

  var account = const <OrderRef>[];
  if (ref.watch(currentUserProvider) != null) {
    try {
      account = await repository.fetchAccountOrderRefs();
    } catch (_) {
      // Account history is a bonus; the device's own orders still show.
    }
  }

  final byId = <String, OrderRef>{for (final r in [...local, ...account]) r.id: r};
  final summaries = await repository.listSummaries(byId.values.toList());
  summaries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return summaries;
});
