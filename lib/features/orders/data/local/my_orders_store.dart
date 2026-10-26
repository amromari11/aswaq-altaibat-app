import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/order_ref.dart';

const _key = 'my_orders';
const _maxKept = 50;

/// The orders this device has placed (`{id, token}`), newest first, kept on the
/// device so a guest — who has no account to list orders from — can find them
/// again. A signed-in customer also gets their account's orders merged in by
/// the orders list.
class MyOrderRefsNotifier extends AsyncNotifier<List<OrderRef>> {
  @override
  Future<List<OrderRef>> build() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return const [];
      return [
        for (final entry in (jsonDecode(raw) as List)) OrderRef.fromJson(Map<String, dynamic>.from(entry as Map)),
      ];
    } catch (_) {
      return const []; // storage unavailable or unreadable: behave as empty
    }
  }

  Future<void> add(OrderRef ref) async {
    // Wait for the initial load from disk first: this notifier is created
    // lazily (checkout is usually its first use), and a load that finishes
    // *after* we set state would overwrite the order we just added.
    final current = await future;
    final next = [ref, ...current.where((r) => r.id != ref.id)].take(_maxKept).toList();
    state = AsyncData(next);
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final r in next) r.toJson()]));
    } catch (_) {
      // Held in memory for this session; just won't survive a restart.
    }
  }
}

final myOrderRefsProvider = AsyncNotifierProvider<MyOrderRefsNotifier, List<OrderRef>>(MyOrderRefsNotifier.new);
