import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/order_change.dart';
import '../../domain/entities/order_ref.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/order_tracking.dart';

/// Reads orders the way a guest can: by `{id, token}` through the
/// `get_order_tracking` / `list_orders_summary` database functions (backend
/// supabase/009), and listens for live status changes on the token's
/// Realtime channel.
class OrderTrackingRepository {
  OrderTrackingRepository(this._client);

  final SupabaseClient _client;

  /// The order, or null if the id/token pair doesn't match anything.
  Future<OrderTracking?> fetchTracking(OrderRef ref) async {
    final json = await _client.rpc('get_order_tracking', params: {
      'p_order_id': ref.id,
      'p_token': ref.token,
    });
    if (json == null) return null;
    return OrderTracking.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Summaries for [refs] (the database ignores any whose token doesn't
  /// match), newest first.
  Future<List<OrderSummary>> listSummaries(List<OrderRef> refs) async {
    if (refs.isEmpty) return const [];
    final tokenById = {for (final r in refs) r.id: r.token};
    final rows = await _client.rpc('list_orders_summary', params: {
      'p_refs': [for (final r in refs.take(50)) r.toJson()],
    });
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        OrderSummary(
          ref: OrderRef(id: row['id'] as String, token: tokenById[row['id'] as String]!),
          status: OrderStatus.fromString(row['status'] as String?),
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          total: (row['total_price'] as num).toDouble(),
          itemCount: (row['item_count'] as num).toInt(),
          zoneName: row['zone_name_ar'] as String?,
        ),
    ];
  }

  /// A signed-in customer's own orders from the server (their account's rows,
  /// via row-level security) — so history follows them across devices.
  Future<List<OrderRef>> fetchAccountOrderRefs() async {
    final rows = await _client
        .from('orders')
        .select('id, tracking_token')
        .order('created_at', ascending: false)
        .limit(50);
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        OrderRef(id: row['id'] as String, token: row['tracking_token'] as String),
    ];
  }

  /// Live changes for [ref], from its Realtime channel (the channel name embeds
  /// the secret token, so only this device is listening):
  ///  * a `status` broadcast, and every (re)connect — so a change missed while
  ///    offline is caught on reconnect — emit [OrderRefreshNeeded];
  ///  * a `driver` broadcast emits [DriverMoved] with the new position.
  Stream<OrderChange> changes(OrderRef ref) {
    late final StreamController<OrderChange> controller;
    RealtimeChannel? channel;
    controller = StreamController<OrderChange>(
      onListen: () {
        channel = _client
            .channel('order:${ref.token}')
            .onBroadcast(event: 'status', callback: (_) => controller.add(const OrderRefreshNeeded()))
            .onBroadcast(
              event: 'driver',
              callback: (payload) {
                try {
                  controller.add(DriverMoved(DriverLocation.fromJson(payload)));
                } catch (_) {
                  // A malformed payload is just a missed ping; fall back to a fetch.
                  controller.add(const OrderRefreshNeeded());
                }
              },
            )
            .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) controller.add(const OrderRefreshNeeded());
        });
      },
      onCancel: () async {
        final active = channel;
        if (active != null) await _client.removeChannel(active);
      },
    );
    return controller.stream;
  }
}
